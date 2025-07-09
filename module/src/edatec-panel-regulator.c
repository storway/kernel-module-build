// SPDX-License-Identifier: GPL-2.0
/*
 * Copyright (C) 2020 Marek Vasut <marex@denx.de>
 *
 * Based on rpi_touchscreen.c by Eric Anholt <eric@anholt.net>
 */

#include <linux/backlight.h>
#include <linux/err.h>
#include <linux/gpio.h>
#include <linux/gpio/driver.h>
#include <linux/i2c.h>
#include <linux/init.h>
#include <linux/interrupt.h>
#include <linux/module.h>
#include <linux/regmap.h>
#include <linux/regulator/driver.h>
#include <linux/regulator/machine.h>
#include <linux/regulator/of_regulator.h>
#include <linux/slab.h>

#define REG_PWM		0x01
#define REG_IODIR	0x02
#define REG_OUTPUT	0x0A

#define PIN_LCD_BL_EN	BIT(0)
#define PIN_LCD_BL_PWM	BIT(1)
#define PIN_LCD_RST		BIT(2)
#define PIN_TP_RST		BIT(3)
#define PIN_LCD_VDD_EN	BIT(4)

enum gpio_signals {
	LCD_BL_EN_N,
	LCD_BL_PWM_N,
	LCD_RST_N,
	TP_RST_N,
	LCD_VDD_EN_N,
	NUM_GPIO
};

struct gpio_signal_mappings {
	unsigned int reg;
	unsigned int mask;
};

static const struct gpio_signal_mappings mappings[NUM_GPIO] = {
	[LCD_BL_EN_N] = { REG_OUTPUT, PIN_LCD_BL_EN },
	[LCD_BL_PWM_N] = { REG_OUTPUT, PIN_LCD_BL_PWM },
	[LCD_RST_N] = { REG_OUTPUT, PIN_LCD_RST },
	[TP_RST_N] = { REG_OUTPUT, PIN_TP_RST },
	[LCD_VDD_EN_N] = { REG_OUTPUT, PIN_LCD_VDD_EN },
};

struct attiny_lcd {
	struct mutex	lock;
	struct regmap	*regmap;
	bool gpio_states[NUM_GPIO];
	u8 port_states;

	struct gpio_chip gc;
};

static const struct regmap_config attiny_regmap_config = {
	.reg_bits = 8,
	.val_bits = 8,
	.disable_locking = 1,
	.max_register = REG_OUTPUT,
	.cache_type = REGCACHE_RBTREE,
};

static int attiny_set_port_state(struct attiny_lcd *state, int reg, u8 val)
{
	state->port_states = val;
	return regmap_write(state->regmap, reg, val);
};

static u8 attiny_get_port_state(struct attiny_lcd *state, int reg)
{
	return state->port_states;
};

static int attiny_update_status(struct backlight_device *bl)
{
	struct attiny_lcd *state = bl_get_data(bl);
	struct regmap *regmap = state->regmap;
	int brightness = backlight_get_brightness(bl);
	int ret, i;

	mutex_lock(&state->lock);

	for (i = 0; i < 10; i++) {
		ret = regmap_write(regmap, REG_PWM, brightness);
		if (!ret)
			break;
	}

	mutex_unlock(&state->lock);

	return ret;
}

static const struct backlight_ops attiny_bl = {
	.update_status	= attiny_update_status,
};

static int attiny_gpio_get_direction(struct gpio_chip *gc, unsigned int off)
{
	return GPIO_LINE_DIRECTION_OUT;
}

static int attiny_set_bit(struct attiny_lcd *state, unsigned int reg, unsigned int pin, bool enabled)
{
	unsigned int mask = BIT(pin);
	unsigned int val  = enabled ? 0xffff : 0x0000;
	
	return regmap_update_bits(state->regmap, reg, mask, val);
}

static int attiny_direction_input(struct gpio_chip *gc, unsigned int off)
{
	struct attiny_lcd *state = gpiochip_get_data(gc);
	int status;
	
	mutex_lock(&state->lock);
	status = attiny_set_bit(state, REG_IODIR, off, true);	    
	mutex_unlock(&state->lock);
	
	return status;	
}

static int attiny_direction_output(struct gpio_chip *gc, unsigned int off, int value)
{
	struct attiny_lcd *state = gpiochip_get_data(gc);
	int status;
	u8 last_val;

	mutex_lock(&state->lock);
	status = attiny_set_bit(state, REG_IODIR, off, false);
	
	last_val = attiny_get_port_state(state, mappings[off].reg);
	if (value)
		last_val |= mappings[off].mask;
	else
		last_val &= ~mappings[off].mask;

	attiny_set_port_state(state, mappings[off].reg, last_val);
	
	mutex_unlock(&state->lock);
	
	return status;
}

static void attiny_gpio_set(struct gpio_chip *gc, unsigned int off, int val)
{
	struct attiny_lcd *state = gpiochip_get_data(gc);
	u8 last_val;

	if (off >= NUM_GPIO)
		return;

	mutex_lock(&state->lock);

	last_val = attiny_get_port_state(state, mappings[off].reg);
	if (val)
		last_val |= mappings[off].mask;
	else
		last_val &= ~mappings[off].mask;

	attiny_set_port_state(state, mappings[off].reg, last_val);

	mutex_unlock(&state->lock);
}

static int attiny_gpio_get(struct gpio_chip *gc, unsigned int off)
{
	struct attiny_lcd *state = gpiochip_get_data(gc);
	u8 last_val;
	int status;
	
	if (off >= NUM_GPIO)
	return -1;

	mutex_lock(&state->lock);
	last_val = attiny_get_port_state(state, mappings[off].reg);
	status = !!(last_val & BIT(off));
	mutex_unlock(&state->lock);
	
	return status;
}

/*
 * I2C driver interface functions
 */
static int attiny_i2c_probe(struct i2c_client *i2c)
{
	struct backlight_properties props = { };
	struct backlight_device *bl;
	struct attiny_lcd *state;
	struct regmap *regmap;
	int ret;

	state = devm_kzalloc(&i2c->dev, sizeof(*state), GFP_KERNEL);
	if (!state)
		return -ENOMEM;

	mutex_init(&state->lock);
	i2c_set_clientdata(i2c, state);

	regmap = devm_regmap_init_i2c(i2c, &attiny_regmap_config);
	if (IS_ERR(regmap)) {
		ret = PTR_ERR(regmap);
		dev_err(&i2c->dev, "Failed to allocate register map: %d\n",
			ret);
		goto error;
	}

	props.type = BACKLIGHT_RAW;
	props.max_brightness = 0xff;
	props.brightness = 0xff;

	state->regmap = regmap;

	bl = devm_backlight_device_register(&i2c->dev, dev_name(&i2c->dev),
					    &i2c->dev, state, &attiny_bl,
					    &props);
	if (IS_ERR(bl)) {
		ret = PTR_ERR(bl);
		goto error;
	}

	bl->props.brightness = 0xff;

	state->gc.parent = &i2c->dev;
	state->gc.label = i2c->name;
	state->gc.owner = THIS_MODULE;
	state->gc.base = -1;
	state->gc.ngpio = NUM_GPIO;

	state->gc.set = attiny_gpio_set;
	state->gc.get = attiny_gpio_get;
	state->gc.get_direction = attiny_gpio_get_direction;
	state->gc.direction_input = attiny_direction_input;
	state->gc.direction_output = attiny_direction_output;
	state->gc.can_sleep = true;

	ret = devm_gpiochip_add_data(&i2c->dev, &state->gc, state);
	if (ret) {
		dev_err(&i2c->dev, "Failed to create gpiochip: %d\n", ret);
		goto error;
	}

	return 0;

error:
	mutex_destroy(&state->lock);

	return ret;
}

static void attiny_i2c_remove(struct i2c_client *client)
{
	struct attiny_lcd *state = i2c_get_clientdata(client);

	mutex_destroy(&state->lock);
}

static const struct of_device_id attiny_dt_ids[] = {
	{ .compatible = "edatec,disp-regulator" },
	{},
};
MODULE_DEVICE_TABLE(of, attiny_dt_ids);

static struct i2c_driver attiny_regulator_driver = {
	.driver = {
		.name = "edatec_touchscreen_attiny",
		.of_match_table = of_match_ptr(attiny_dt_ids),
	},
	.probe = attiny_i2c_probe,
	.remove	= attiny_i2c_remove,
};

module_i2c_driver(attiny_regulator_driver);

MODULE_AUTHOR("Marek Vasut <marex@denx.de>");
MODULE_DESCRIPTION("Regulator device driver for Raspberry Pi 7-inch touchscreen");
MODULE_LICENSE("GPL v2");

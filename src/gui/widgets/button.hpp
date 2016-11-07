/*
   Copyright (C) 2008 - 2016 by Mark de Wever <koraq@xs4all.nl>
   Part of the Battle for Wesnoth Project http://www.wesnoth.org/

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY.

   See the COPYING file for more details.
*/

#ifndef GUI_WIDGETS_BUTTON_HPP_INCLUDED
#define GUI_WIDGETS_BUTTON_HPP_INCLUDED

#include "gui/core/widget_definition.hpp"
#include "gui/core/window_builder.hpp"

#include "gui/widgets/control.hpp"
#include "gui/widgets/clickable.hpp"

namespace gui2
{

// ------------ WIDGET -----------{

/**
 * Simple push button.
 */
class tbutton : public tcontrol, public tclickable_
{
public:
	tbutton();

	/***** ***** ***** ***** Inherited ***** ***** ***** *****/

	/** See @ref tcontrol::set_active. */
	virtual void set_active(const bool active) override;

	/** See @ref tcontrol::get_active. */
	virtual bool get_active() const override;

	/** See @ref tcontrol::get_state. */
	virtual unsigned get_state() const override;

	/** Inherited from tclickable. */
	void connect_click_handler(const event::signal_function& signal) override
	{
		connect_signal_mouse_left_click(*this, signal);
	}

	/** Inherited from tclickable. */
	void disconnect_click_handler(const event::signal_function& signal) override
	{
		disconnect_signal_mouse_left_click(*this, signal);
	}

	/***** ***** ***** setters / getters for members ***** ****** *****/

	void set_retval(const int retval)
	{
		retval_ = retval;
	}

private:
	/**
	 * Possible states of the widget.
	 *
	 * Note the order of the states must be the same as defined in settings.hpp.
	 */
	enum state_t {
		ENABLED,
		DISABLED,
		PRESSED,
		FOCUSED,
		COUNT
	};

	void set_state(const state_t state);
	/**
	 * Current state of the widget.
	 *
	 * The state of the widget determines what to render and how the widget
	 * reacts to certain 'events'.
	 */
	state_t state_;

	/**
	 * The return value of the button.
	 *
	 * If this value is not 0 and the button is clicked it sets the retval of
	 * the window and the window closes itself.
	 */
	int retval_;

	/** See @ref tcontrol::get_control_type. */
	virtual const std::string& get_control_type() const override;

	/***** ***** ***** signal handlers ***** ****** *****/

	void signal_handler_mouse_enter(const event::event_t event, bool& handled);

	void signal_handler_mouse_leave(const event::event_t event, bool& handled);

	void signal_handler_left_button_down(const event::event_t event,
										 bool& handled);

	void signal_handler_left_button_up(const event::event_t event,
									   bool& handled);

	void signal_handler_left_button_click(const event::event_t event,
										  bool& handled);
};

// }---------- DEFINITION ---------{

struct button_definition : public control_definition
{
	explicit button_definition(const config& cfg);

	struct tresolution : public resolution_definition
	{
		explicit tresolution(const config& cfg);
	};
};

// }---------- BUILDER -----------{

class tcontrol;

namespace implementation
{

struct builder_button : public builder_control
{
public:
	explicit builder_button(const config& cfg);

	using builder_control::build;

	twidget* build() const;

private:
	std::string retval_id_;
	int retval_;
};

} // namespace implementation

// }------------ END --------------

} // namespace gui2

#endif

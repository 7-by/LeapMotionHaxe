package net.sevenby7.leapmotion.events;

import net.sevenby7.leapmotion.Frame;
import openfl.events.Event;

/**
 * ...
 * @author 7-by
 */
class LeapEvent extends Event
{
	public static inline var LEAPMOTION_INIT:String = 'leapmotionInit';
	public static inline var LEAPMOTION_CONNECTED:String = 'leapmotionConnected';
	public static inline var LEAPMOTION_DISCONNECTED:String = 'leapmotionDisconnected';
	public static inline var LEAPMOTION_TIMEOUT:String = 'leapmotionTimeout';
	public static inline var LEAPMOTION_EXIT:String = 'leapmotionExit';
	public static inline var LEAPMOTION_FOCUSGAINED:String = 'leapmotionFocusGained';
	public static inline var LEAPMOTION_FOCUSLOST:String = 'leapmotionFocusLost';
	public static inline var LEAPMOTION_FRAME:String = 'leapmotionFrame';
	
	public var frame:Frame;

	public function new(type:String, ?frame:Frame) 
	{
		this.frame = frame;
		super(type, false, false);
	}
	
}
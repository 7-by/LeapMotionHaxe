package net.sevenby7.leapmotion.interfaces;
import net.sevenby7.leapmotion.events.LeapEvent;
import net.sevenby7.leapmotion.Frame;
import net.sevenby7.leapmotion.Controller;

/**
 * ...
 * @author 7-by
 */
class DefaultListener implements IListener
{

	public function new() 
	{
		
	}
	
	public function onConnect(controller:Controller):Void 
	{
		controller.dispatchEvent(new LeapEvent(LeapEvent.LEAPMOTION_CONNECTED));
	}
	
	public function onDisconnect(controller:Controller):Void 
	{
		controller.dispatchEvent(new LeapEvent(LeapEvent.LEAPMOTION_DISCONNECTED));
	}
	
	public function onExit(controller:Controller):Void 
	{
		controller.dispatchEvent(new LeapEvent(LeapEvent.LEAPMOTION_EXIT));
	}
	
	public function onFocusGained(controller:Controller):Void 
	{
		controller.dispatchEvent(new LeapEvent(LeapEvent.LEAPMOTION_FOCUSGAINED));
	}
	
	public function onFocusLost(controller:Controller):Void 
	{
		controller.dispatchEvent(new LeapEvent(LeapEvent.LEAPMOTION_FOCUSLOST));
	}
	
	public function onFrame(controller:Controller, frame:Frame):Void 
	{
		controller.dispatchEvent(new LeapEvent(LeapEvent.LEAPMOTION_FRAME, frame));
	}
	
	public function onInit(controller:Controller):Void 
	{
		controller.dispatchEvent(new LeapEvent(LeapEvent.LEAPMOTION_INIT));
	}
	
}
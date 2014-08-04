package net.sevenby7.leapmotion.native;

import net.sevenby7.leapmotion.Frame;
import net.sevenby7.leapmotion.interfaces.ILeapConnection;

/**
 * ...
 * @author 7-by
 */
class LeapNative implements ILeapConnection
{
	public var isConnected(default, null):Bool;
	public var isServiceConnected(default, null):Bool;
	public var frame(default, null):Frame;

	public function new() 
	{
		
	}
	
	public function enableGesture(gesture:Int, enable:Bool):Void 
	{
		
	}
	
	public function isGestureEnabled(gesture:Int):Bool 
	{
		return true;
	}
	
	public function policyFlags():Int 
	{
		return 0;
	}
	
	public function setPolicyFlags(flags:Int):Void 
	{
		
	}
	
}
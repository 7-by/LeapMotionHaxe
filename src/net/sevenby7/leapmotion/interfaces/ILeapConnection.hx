package net.sevenby7.leapmotion.interfaces;

/**
 * @author 7-by
 */

interface ILeapConnection 
{
	public var isConnected(default, null):Bool;
	public var isServiceConnected(default, null):Bool;
	public var frame(default, null):Frame;
	public var isGestureEnabled(default, null):Bool;
	public function enableGesture(gesture:Int, enable:Bool):Void;
	public function policyFlags():Int;
	public function setPolicyFlags(flags:Int):Void;
}
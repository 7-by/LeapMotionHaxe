package net.sevenby7.leapmotion.socket;

import net.sevenby7.leapmotion.Controller;
import net.sevenby7.leapmotion.Frame;
import net.sevenby7.leapmotion.interfaces.ILeapConnection;
import openfl.events.EventDispatcher;
import openfl.net.Socket;

/**
 * ...
 * @author 7-by
 */
class LeapSocket extends EventDispatcher implements ILeapConnection
{
	public var isConnected(default, null):Bool;
	public var isServiceConnected(default, null):Bool;
	public var frame(default, null):Frame;
	
	private static inline var STATE_CONNECTING:Int = 0;
	private static inline var STATE_VERSION:Int = 1;
	private static inline var STATE_OPEN:Int = 1;
	
	private var _socket:Socket;
	private var _currentState:Int;
	private var _controller:Controller;
	private var _host:String = 'localhost';
	private var _port:Int = 6437;
	private var _protocol:Int = 6;
	private var _handshakeBytesReceived:Int;
	private var _leapMotionDeviceHandshakeResponse:String = '';
	private var _base64nonce:String;
	private var _leapSocketFrame:String;

	public inline function new() 
	{
		super();
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
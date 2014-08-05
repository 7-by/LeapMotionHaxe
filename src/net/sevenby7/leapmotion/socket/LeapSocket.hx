package net.sevenby7.leapmotion.socket;

import haxe.Json;
import net.sevenby7.leapmotion.Controller;
import net.sevenby7.leapmotion.Frame;
import net.sevenby7.leapmotion.interfaces.ILeapConnection;
import net.sevenby7.leapmotion.util.Base64Encoder;
import openfl.errors.Error;
import openfl.errors.SecurityError;
import openfl.events.Event;
import openfl.events.EventDispatcher;
import openfl.events.IOErrorEvent;
import openfl.events.ProgressEvent;
import openfl.events.SecurityErrorEvent;
import openfl.external.ExternalInterface;
import openfl.net.Socket;
import openfl.system.Capabilities;
import openfl.utils.ByteArray;
import openfl.utils.Endian;
import openfl.utils.Object;

/**
 * ...
 * @author 7-by
 */
class LeapSocket extends EventDispatcher implements ILeapConnection
{
	public var isConnected(default, null):Bool;
	public var isServiceConnected(default, null):Bool;
	public var frame(default, null):Frame;
	public var isGestureEnabled(default, null):Bool;
	
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
	private var _output:ByteArray;
	private var _binaryPayload:ByteArray;

	public function new(controller:Controller, ?host:String, port:Int = 6437) 
	{
		super();
		
		if (host != null && host != '')
			_host = host;
			
		if (port != null)
			_port = port;
			
		_controller = controller;
		
		if( Capabilities.playerType == "PlugIn" && ExternalInterface.available )
		{
			try
			{
				ExternalInterface.addCallback( "data", parseExternalData );
				ExternalInterface.call( "ready" );
				_currentState = STATE_VERSION;
			}
			catch(error:SecurityError)
			{
				trace("LeapMotionAS3 (websocket proxy fallback) SecurityError occurred: " + error.message + "\n");
			}
			catch(error:Error)
			{
				trace("LeapMotionAS3 (websocket proxy fallback) Error occurred: " + error.message + "\n");
			}
		}
		
		var nonce:ByteArray = new ByteArray();
		for (i in 0...16)
			nonce.writeByte(Math.round(Math.random() * 0xFF));
		
		nonce.position = 0;
		
		var encoder:Base64Encoder = new Base64Encoder();
		encoder.encodeBytes(nonce);
		_base64nonce = encoder.flush();
		
		_binaryPayload = new ByteArray();
		_output = new ByteArray();
		
		_socket = new Socket();
		_socket.addEventListener( Event.CONNECT, onSocketConnectHandler );
		_socket.addEventListener( IOErrorEvent.IO_ERROR, onIOErrorHandler );
		_socket.addEventListener( SecurityErrorEvent.SECURITY_ERROR, onSecurityErrorHandler );
		_socket.addEventListener( ProgressEvent.SOCKET_DATA, onSocketDataHandler );
		_socket.connect(_host, _port);
		
		addEventListener('throttle', onThrottleHandler);
	}
	
	private function onSocketConnectHandler(e:Event):Void 
	{
		isConnected = false;
		_controller._listener.onInit(_controller);
		_currentState = STATE_CONNECTING;
		_socket.endian = Endian.BIG_ENDIAN;
		sendHandshake();
	}
	
	public function parseExternalData(utf8data:String):Void
	{
		parseJSON(Json.parse(utf8data));
	}
	
	private function onThrottleHandler(e:Object):Void
	{
		switch (e.state) 
		{
			case 'pause', 'throttle':
				sendUTF("{\"focused\": false}");
			case 'resume':
				sendUTF( "{\"focused\": true}" );
		}
	}
	
	public function enableGesture(gesture:Int, enable:Bool):Void 
	{
		
	}
	
	public function policyFlags():Int 
	{
		return 0;
	}
	
	public function setPolicyFlags(flags:Int):Void 
	{
		
	}
	
}
package net.sevenby7.leapmotion.socket;

import net.sevenby7.leapmotion.gestures.KeyTapGesture;
import net.sevenby7.leapmotion.gestures.ScreenTapGesture;
import net.sevenby7.leapmotion.gestures.SwipeGesture;
import net.sevenby7.leapmotion.gestures.SwipeGesture;
import net.sevenby7.leapmotion.gestures.CircleGesture;
import net.sevenby7.leapmotion.gestures.Gesture;
import flash.geom.Matrix;
import flash.events.SecurityErrorEvent;
import flash.net.Socket;
import flash.system.Capabilities;
import flash.events.ThrottleEvent;
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
import openfl.external.ExternalInterface;
import openfl.utils.ByteArray;
import openfl.utils.Endian;

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
	private static inline var STATE_OPEN:Int = 3;

	private var _socket:Socket;
	private var _currentState:Int;
	private var _controller:Controller;
	private var _host:String = 'localhost';
	private var _port:Int = 6437;
	private var _protocol:Int = 6;
	private var _handshakeBytesReceived:Int;
	private var _leapMotionDeviceHandshakeResponse:String = '';
	private var _base64nonce:String;
	private var _leapSocketFrame:LeapSocketFrame;
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

		if (Capabilities.playerType == "PlugIn" && ExternalInterface.available)
		{
			try
			{
				ExternalInterface.addCallback("data", parseExternalData);
				ExternalInterface.call("ready");
				_currentState = STATE_VERSION;
			}
			catch (error:SecurityError)
			{
				trace("LeapMotionAS3 (websocket proxy fallback) SecurityError occurred: " + error.message + "\n");
			}
			catch (error:Error)
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
		_socket.addEventListener(Event.CONNECT, onSocketConnectHandler);
		_socket.addEventListener(IOErrorEvent.IO_ERROR, onIOErrorHandler);
		_socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityErrorHandler);
		_socket.addEventListener(ProgressEvent.SOCKET_DATA, onSocketDataHandler);
		_socket.connect(_host, _port);

		addEventListener('throttle', onThrottleHandler);
	}

	private function onSecurityErrorHandler(e:Event):Void
	{
		onError();
	}

	private function onIOErrorHandler(e:Event):Void
	{
		onError();
	}

	private function onSocketCloseHandler(e:Event):Void
	{
		onError();
		_controller._listener.onExit(_controller);
	}

	private inline function onError():Void
	{
		isConnected = false;
		_controller._listener.onDisconnect(_controller);
		removeEventListener(ThrottleEvent.THROTTLE, onThrottleHandler);
	}

	private inline function onSocketDataHandler(e:Event):Void
	{
		if (_currentState == STATE_CONNECTING)
			readLeapMotionHandshake();

		isConnected = true;

		var utf8data:String;

// Loop until data has been completely added to the frame
		while (_socket.connected && _leapSocketFrame.addData(_socket))
		{
			_leapSocketFrame.binaryPayload.position = 0;
			utf8data = _leapSocketFrame.binaryPayload.readUTFBytes(_leapSocketFrame.length);
			parseJSON(Json.parse(utf8data));

// Release current frame and create a new one
			_leapSocketFrame = new LeapSocketFrame();
		}
	}

	private function onSocketConnectHandler(e:Event):Void
	{
		isConnected = false;
		_controller._listener.onInit(_controller);
		_currentState = STATE_CONNECTING;
		_socket.endian = Endian.BIG_ENDIAN;
		sendHandshake();
	}

	private inline function parseJSON(json:Dynamic):Void
	{
		var i:UInt;
		var currentFrame:Frame;
		var hand:Hand;
		var arm:Arm;
		var armDisplacement:Vector3;
		var armLength:Float;
		var pointable:Pointable;
		var bone:Bone;
		var gesture:Gesture;
		var isTool:Bool;
		var length:UInt;
		var type:UInt;

// Server-side events. Currently only deviceConnect events are supported.
		if (json.event)
		{
			switch (json.event.type)
			{
				case 'deviceConnect':
					if (json.event.state == true)
					{
						isConnected = true;
						_controller._listener.onConnect(_controller);
					}
					else
					{
						isConnected = false;
						_controller._listener.onDisconnect(_controller);
					}
			}

			return;
		}

		currentFrame = new Frame();
		currentFrame.controller = controller;

// Hands
		if (json.hands)
		{
			i = 0;
			length = json.hands.length;
			for (i in 0...length)
			{
				hand = new Hand();
				hand.frame = currentFrame;
				hand.direction = new Vector3(json.hands[i].direction[0], json.hands[i].direction[1], json.hands[i].direction[2]);
				hand.id = json.hands[i].id;
				hand.palmNormal = new Vector3(json.hands[i].palmNormal[0], json.hands[i].palmNormal[1], json.hands[i].palmNormal[2]);
				hand.palmPosition = new Vector3(json.hands[i].palmPosition[0], json.hands[i].palmPosition[1], json.hands[i].palmPosition[2]);
				hand.palmWidth = json.hands[i].palmWidth;
				hand.stabilizedPalmPosition = new Vector3(json.hands[i].stabilizedPalmPosition[0], json.hands[i].stabilizedPalmPosition[1], json.hands[i].stabilizedPalmPosition[2]);
				hand.palmVelocity = new Vector3(json.hands[i].palmPosition[0], json.hands[i].palmPosition[1], json.hands[i].palmPosition[2]);
				hand.rotation = new Matrix(new Vector3(json.hands[i].r[0][0], json.hands[i].r[0][1], json.hands[i].r[0][2]), new Vector3(json.hands[i].r[1][0], json.hands[i].r[1][1], json.hands[i].r[1][2]), new Vector3(json.hands[i].r[2][0], json.hands[i].r[2][1], json.hands[i].r[2][2]));
				hand.scaleFactorNumber = json.hands[i].s;
				hand.sphereCenter = new Vector3(json.hands[i].sphereCenter[0], json.hands[i].sphereCenter[1], json.hands[i].sphereCenter[2]);
				hand.sphereRadius = json.hands[i].sphereRadius;
				hand.timeVisible = json.hands[i].timeVisible;
				hand.isLeft = json.hands[i].isLeft;
				hand.isRight = json.hands[i].isRight;
				hand.pinchStrength = json.hands[i].pinchStrength;
				hand.grabStrength = json.hands[i].grabStrength;
				hand.translationVector = new Vector3(json.hands[i].t[0], json.hands[i].t[1], json.hands[i].t[2]);

// Arm
				if (json.hands[i].armBasis)
				{
					arm = new Arm();
					arm.basis = new Matrix(new Vector3(json.hands[i].armBasis[0][0], json.hands[i].armBasis[0][1], json.hands[i].armBasis[0][2]), new Vector3(json.hands[i].armBasis[1][0], json.hands[i].armBasis[1][1], json.hands[i].armBasis[1][2]), new Vector3(json.hands[i].armBasis[2][0], json.hands[i].armBasis[2][1], json.hands[i].armBasis[2][2]));
					arm.elbowPosition = new Vector3(json.hands[i].elbow[0], json.hands[i].elbow[1], json.hands[i].elbow[2]);
					arm.wristPosition = new Vector3(json.hands[i].wrist[0], json.hands[i].wrist[1], json.hands[i].wrist[2]);
					arm.width = json.hands[i].armWidth;
					armDisplacement = arm.elbowPosition.minus(arm.wristPosition);
					armLength = armDisplacement.magnitude();
					arm.length = armLength;
					hand.arm = arm;
				}
				else
				{
					hand.arm = Arm.invalid();
				}
				currentFrame.hands.push(hand);
			}
		}

// The current framerate (in frames per second) of the Leap Motion Controller.
		currentFrame.currentFramesPerSecond = json.currentFramesPerSecond;

// A unique ID for this Frame.
		currentFrame.id = json.id;

// The InteractionBox class represents a box-shaped region completely within the field of view.
		if (json.interactionBox)
		{
			currentFrame.interactionBox = new InteractionBox();
			currentFrame.interactionBox.center = new Vector3(json.interactionBox.center[0], json.interactionBox.center[1], json.interactionBox.center[2]);
			currentFrame.interactionBox.width = json.interactionBox.size[0];
			currentFrame.interactionBox.height = json.interactionBox.size[1];
			currentFrame.interactionBox.depth = json.interactionBox.size[2];
		}

// Pointables
		if (json.pointables)
		{
			i = 0;
			length = json.pointables.length;
			for (i in 0...length)
			{
				isTool = json.pointables[i].tool;
				if (isTool)
					pointable = new Tool();
				else
					pointable = new Finger();

				pointable.frame = currentFrame;
				pointable.id = json.pointables[i].id;
				pointable.hand = getHandByID(currentFrame, json.pointables[i].handId);
				pointable.length = json.pointables[i].length;
				pointable.direction = new Vector3(json.pointables[i].direction[0], json.pointables[i].direction[1], json.pointables[i].direction[2]);
				pointable.tipPosition = new Vector3(json.pointables[i].tipPosition[0], json.pointables[i].tipPosition[1], json.pointables[i].tipPosition[2]);
				pointable.btipPosition = new Vector3(json.pointables[i].btipPosition[0], json.pointables[i].btipPosition[1], json.pointables[i].btipPosition[2]);
				pointable.stabilizedTipPosition = new Vector3(json.pointables[i].stabilizedTipPosition[0], json.pointables[i].stabilizedTipPosition[1], json.pointables[i].stabilizedTipPosition[2]);
				pointable.timeVisible = json.pointables[i].timeVisible;
				pointable.touchDistance = json.pointables[i].touchDistance;

				switch (json.pointables[i].touchZone)
				{
					case "hovering":
						pointable.touchZone = Pointable.ZONE_HOVERING;
					case "touching":
						pointable.touchZone = Pointable.ZONE_TOUCHING;
					default:
						pointable.touchZone = Pointable.ZONE_NONE;
				}
				pointable.tipVelocity = new Vector3(json.pointables[i].tipVelocity[0], json.pointables[i].tipVelocity[1], json.pointables[i].tipVelocity[2]);
				currentFrame.pointables.push(pointable);

				if (pointable.hand)
					pointable.hand.pointables.push(pointable);

				if (isTool)
				{
					pointable.isTool = true;
					pointable.isFinger = false;
					pointable.isExtended = true;
					pointable.width = json.pointables[i].width;
					currentFrame.tools.push(pointable);
					if (pointable.hand)
						pointable.hand.tools.push(pointable);
				}
				else
				{
					pointable.isTool = false;
					pointable.isFinger = true;
					pointable.isExtended = json.pointables[i].extended;
					Finger(pointable).dipPosition = new Vector3(json.pointables[i].dipPosition[0], json.pointables[i].dipPosition[1], json.pointables[i].dipPosition[2]);
					Finger(pointable).pipPosition = new Vector3(json.pointables[i].pipPosition[0], json.pointables[i].pipPosition[1], json.pointables[i].pipPosition[2]);
					Finger(pointable).mcpPosition = new Vector3(json.pointables[i].mcpPosition[0], json.pointables[i].mcpPosition[1], json.pointables[i].mcpPosition[2]);
					Finger(pointable).type = json.pointables[i].type;

// Bones
					bone = new Bone();
					bone.type = Bone.TYPE_METACARPAL;
					bone.width = json.pointables[i].width;
					bone.length = json.pointables[i].length;
					bone.prevJoint = new Vector3(json.pointables[i].carpPosition[0], json.pointables[i].carpPosition[1], json.pointables[i].carpPosition[2]);
					bone.nextJoint = new Vector3(json.pointables[i].mcpPosition[0], json.pointables[i].mcpPosition[1], json.pointables[i].mcpPosition[2]);
					bone.basis = new Matrix(new Vector3(json.pointables[i].bases[0][0][0], json.pointables[i].bases[0][0][1], json.pointables[i].bases[0][0][2]), new Vector3(json.pointables[i].bases[0][1][0], json.pointables[i].bases[0][1][1], json.pointables[i].bases[0][1][2]), new Vector3(json.pointables[i].bases[0][2][0], json.pointables[i].bases[0][2][1], json.pointables[i].bases[0][2][2]));
					Finger(pointable).metacarpal = bone;

					bone = new Bone();
					bone.type = Bone.TYPE_PROXIMAL;
					bone.width = json.pointables[i].width;
					bone.length = json.pointables[i].length;
					bone.prevJoint = new Vector3(json.pointables[i].mcpPosition[0], json.pointables[i].mcpPosition[1], json.pointables[i].mcpPosition[2]);
					bone.nextJoint = new Vector3(json.pointables[i].pipPosition[0], json.pointables[i].pipPosition[1], json.pointables[i].pipPosition[2]);
					bone.basis = new Matrix(new Vector3(json.pointables[i].bases[1][0][0], json.pointables[i].bases[1][0][1], json.pointables[i].bases[1][0][2]), new Vector3(json.pointables[i].bases[1][1][0], json.pointables[i].bases[1][1][1], json.pointables[i].bases[1][1][2]), new Vector3(json.pointables[i].bases[1][2][0], json.pointables[i].bases[1][2][1], json.pointables[i].bases[1][2][2]));
					Finger(pointable).proximal = bone;

					bone = new Bone();
					bone.type = Bone.TYPE_INTERMEDIATE;
					bone.width = json.pointables[i].width;
					bone.length = json.pointables[i].length;
					bone.prevJoint = new Vector3(json.pointables[i].pipPosition[0], json.pointables[i].pipPosition[1], json.pointables[i].pipPosition[2]);
					bone.nextJoint = new Vector3(json.pointables[i].dipPosition[0], json.pointables[i].dipPosition[1], json.pointables[i].dipPosition[2]);
					bone.basis = new Matrix(new Vector3(json.pointables[i].bases[2][0][0], json.pointables[i].bases[2][0][1], json.pointables[i].bases[2][0][2]), new Vector3(json.pointables[i].bases[2][1][0], json.pointables[i].bases[2][1][1], json.pointables[i].bases[2][1][2]), new Vector3(json.pointables[i].bases[2][2][0], json.pointables[i].bases[2][2][1], json.pointables[i].bases[2][2][2]));
					Finger(pointable).intermediate = bone;

					bone = new Bone();
					bone.type = Bone.TYPE_DISTAL;
					bone.width = json.pointables[i].width;
					bone.length = json.pointables[i].length;
					bone.prevJoint = new Vector3(json.pointables[i].dipPosition[0], json.pointables[i].dipPosition[1], json.pointables[i].dipPosition[2]);
					bone.nextJoint = new Vector3(json.pointables[i].btipPosition[0], json.pointables[i].btipPosition[1], json.pointables[i].btipPosition[2]);
					bone.basis = new Matrix(new Vector3(json.pointables[i].bases[3][0][0], json.pointables[i].bases[3][0][1], json.pointables[i].bases[3][0][2]), new Vector3(json.pointables[i].bases[3][1][0], json.pointables[i].bases[3][1][1], json.pointables[i].bases[3][1][2]), new Vector3(json.pointables[i].bases[3][2][0], json.pointables[i].bases[3][2][1], json.pointables[i].bases[3][2][2]));
					Finger(pointable).distal = bone;

					currentFrame.fingers.push(pointable);
					if (pointable.hand)
						pointable.hand.fingers.push(pointable);
				}
			}
		}

// Gestures
		if (json.gestures)
		{
			i = 0;
			length = json.gestures.length;
			for (i in 0...length)
			{
				switch (json.gestures[i].type)
				{
					case "circle":
						gesture = new CircleGesture();
						type = Gesture.TYPE_CIRCLE;
						var circle:CircleGesture = CircleGesture(gesture);
						circle.center = new Vector3(json.gestures[i].center[0], json.gestures[i].center[1], json.gestures[i].center[2]);
						circle.normal = new Vector3(json.gestures[i].normal[0], json.gestures[i].normal[1], json.gestures[i].normal[2]);
						circle.progress = json.gestures[i].progress;
						circle.radius = json.gestures[i].radius;
					case "swipe":
						gesture = new SwipeGesture();
						type = Gesture.TYPE_SWIPE;
						var swipe:SwipeGesture = SwipeGesture(gesture);
						swipe.startPosition = new Vector3(json.gestures[i].startPosition[0], json.gestures[i].startPosition[1], json.gestures[i].startPosition[2]);
						swipe.position = new Vector3(json.gestures[i].position[0], json.gestures[i].position[1], json.gestures[i].position[2]);
						swipe.direction = new Vector3(json.gestures[i].direction[0], json.gestures[i].direction[1], json.gestures[i].direction[2]);
						swipe.speed = json.gestures[i].speed;
					case "screenTap":
						gesture = new ScreenTapGesture();
						type = Gesture.TYPE_SCREEN_TAP;
						var screenTap:ScreenTapGesture = ScreenTapGesture(gesture);
						screenTap.position = new Vector3(json.gestures[i].position[0], json.gestures[i].position[1], json.gestures[i].position[2]);
						screenTap.direction = new Vector3(json.gestures[i].direction[0], json.gestures[i].direction[1], json.gestures[i].direction[2]);
						screenTap.progress = json.gestures[i].progress;
					case "keyTap":
						gesture = new KeyTapGesture();
						type = Gesture.TYPE_KEY_TAP;
						var keyTap:KeyTapGesture = KeyTapGesture(gesture);
						keyTap.position = new Vector3(json.gestures[i].position[0], json.gestures[i].position[1], json.gestures[i].position[2]);
						keyTap.direction = new Vector3(json.gestures[i].direction[0], json.gestures[i].direction[1], json.gestures[i].direction[2]);
						keyTap.progress = json.gestures[i].progress;
					default:
						throw new Error("unkown gesture type");
				}

				var j:Int = 0;
				var lengthInner:Int = 0;

				if (json.gestures[i].handIds)
				{
					j = 0;
					lengthInner = json.gestures[i].handIds.length;
					for (j; j < lengthInner; ++j)
					{
					var gestureHand:Hand = getHandByID(currentFrame, json.gestures[i].handIds[j]);
					gesture.hands.push(gestureHand);
					}
				}

				if (json.gestures[i].pointableIds)
				{
					j = 0;
					lengthInner = json.gestures[i].pointableIds.length;
					for (j; j < lengthInner; ++j)
					{
					var gesturePointable:Pointable = getPointableByID(currentFrame, json.gestures[i].pointableIds[j]);
					if (gesturePointable)
					{
					gesture.pointables.push(gesturePointable);
					}
					}
					if (gesture is CircleGesture && gesture.pointables.length > 0)
					{
					(gesture as CircleGesture).pointable = gesture.pointables[0];
					}
				}

				gesture.frame = currentFrame;
				gesture.id = json.gestures[i].id;
				gesture.duration = json.gestures[i].duration;
				gesture.durationSeconds = gesture.duration / 1000000;

				switch (json.gestures[i].state)
				{
					case "start":
						gesture.state = Gesture.STATE_START;
						break;
					case "update":
						gesture.state = Gesture.STATE_UPDATE;
						break;
					case "stop":
						gesture.state = Gesture.STATE_STOP;
						break;
					default:
						gesture.state = Gesture.STATE_INVALID;
				}

				gesture.type = type;

				currentFrame.gesturesVector.push(gesture);
			}
		}

// Rotation (since last frame), interpolate for smoother motion
		if (json.r)
			currentFrame.rotation = new Matrix(new Vector3(json.r[0][0], json.r[0][1], json.r[0][2]), new Vector3(json.r[1][0], json.r[1][1], json.r[1][2]), new Vector3(json.r[2][0], json.r[2][1], json.r[2][2]));

// Scale factor (since last frame), interpolate for smoother motion
		currentFrame.scaleFactorNumber = json.s;

// Translation (since last frame), interpolate for smoother motion
		if (json.t)
			currentFrame.translationVector = new Vector3(json.t[0], json.t[1], json.t[2]);

// Timestamp
		currentFrame.timestamp = json.timestamp;

		if (currentState == STATE_OPEN)
		{
// Add frame to history
			if (controller.frameHistory.length > 59)
				controller.frameHistory.splice(59, 1);

			controller.frameHistory.unshift(_frame);

			_frame = currentFrame;

			controller.leapmotion::listener.onFrame(controller, _frame);
		}
		else if (currentState == STATE_VERSION && json.version)
		{
			if (json.version != = protocol)
				throw new Error("Please update the Leap App (Invalid protocol version)");

			sendUTF("{\"focused\": true}");

			currentState = STATE_OPEN;
			controller.leapmotion::listener.onConnect(controller);
		}
	}

	public function parseExternalData(utf8data:String):Void
	{
		parseJSON(Json.parse(utf8data));
	}

	private function onThrottleHandler(e:Dynamic):Void
	{
		switch (e.state)
		{
			case 'pause', 'throttle':
				sendUTF("{\"focused\": false}");
			case 'resume':
				sendUTF("{\"focused\": true}");
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
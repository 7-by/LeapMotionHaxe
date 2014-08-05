package net.sevenby7.leapmotion;
import net.sevenby7.leapmotion.interfaces.DefaultListener;
import net.sevenby7.leapmotion.interfaces.ILeapConnection;
import net.sevenby7.leapmotion.interfaces.IListener;
import net.sevenby7.leapmotion.native.LeapNative;
import net.sevenby7.leapmotion.socket.LeapSocket;
import openfl.events.EventDispatcher;
import openfl.utils.Object;
import openfl.Vector;

/**
 * 
 * @author 7-by
 */
class Controller extends EventDispatcher
{
	public static inline var POLICY_DEFAULT:UInt = 0;
	public static inline var POLICY_BACKGROUND_FRAMES:UInt = (1 << 0);
	
	public var _listener:IListener;
	
	public var connection:ILeapConnection;
	public var frameHistory:Vector<Frame> = new Vector<Frame>();
	public var context:Object;
	
	public function new(?host:String, port:Int = 6437) 
	{
		super();
		
		_listener = new DefaultListener();
		
		if (host == null && host == '' /*&& LeapNative.isSupported()*/)
			connection = new LeapNative();
		else
			connection = new LeapSocket(this, host, port);
	}
	
	
	
}
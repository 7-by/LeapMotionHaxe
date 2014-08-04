package net.sevenby7.leapmotion.interfaces;

/**
 * @author 7-by
 */

interface IListener 
{
	function onConnect(controller:Controller):Void;
	function onDisconnect(controller:Controller):Void;
	function onExit(controller:Controller):Void;
	function onFocusGained(controller:Controller):Void;
	function onFocusLost(controller:Controller):Void;
	function onFrame(controller:Controller, frame:Frame):Void;
	function onInit(controller:Controller):Void;
}
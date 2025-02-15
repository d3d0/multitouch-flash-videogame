﻿////////////////////////////////////////////////////////////////////////////////
//
//  IDEUM
//  Copyright 2009-2011 Ideum
//  All Rights Reserved.
//
//  OPEN EXHIBITS SDK (OPEN EXHIBITS CORE)
//
//  File:    	TouchObject.as
//
//  Authors:   	Chris Gerber (chris(at)ideum(dot)com),
//				Matthew Valverde (matthew(at)ideum(dot)com), 
//				Paul Lacey (paul(at)ideum(dot)com).
//
//  NOTICE: OPEN EXHIBITS SDK permits you to use, modify, and distribute this file
//  in accordance with the terms of the license agreement accompanying it.
//
////////////////////////////////////////////////////////////////////////////////

package id.core
{

/*CONFIG::FLASH_AUTHORING
{
;
}

!CONFIG::FLASH_AUTHORING
{
;
}

CONFIG::DEBUG
{
;
}*/

import gl.activators.IActivator;
import gl.gestures.IGesture;
import gl.paths.Path;
//import gl.paths.PathCollection;
import gl.paths.PathProcessor;
import gl.touches.ITouch;

import gl.events.TouchEvent;

import id.core.IDescriptor;
import id.core.IDSprite;
import id.managers.ITactualObjectManagerClient;
import id.managers.TactualObjectManager;
import id.managers.IValidationManagerClient;
import id.tracker.ITracker;
import id.tracker.ITrackerClient;
import id.structs.DescriptorPriorityQueue;
import id.utils.EventUtil;

import flash.display.DisplayObject;
import flash.events.Event;
import flash.events.EventPhase;
import flash.events.IEventDispatcher;
import flash.geom.Matrix;
import flash.geom.Point;
import flash.utils.Dictionary;
import flash.utils.getTimer;

use namespace id_internal;

/**
 * The TouchObject class is the base class for all touch enabled DisplayObjects. It
 * provides basic implementations for priortized gesture and touch processing as well as 
 * properties to dictate tactual object ownership and targeting. This object inherits
 * the Player default Sprite functionality.
 * 
 * <p>All TouchObjects are provided with a static reference to the global blob manager
 * at runtime. A DataProvider to the blob manager is established upon Application 
 * instantiation by the developer.</p>
 * 
 * <pre>
 * 	<b>Properties</b>
 * 	 blobContainer="undefined"
 * 	 blobContainerEnabled="false"
 * 	 topLevel="false"
 * </pre>
 */
public class TouchObject extends IDSprite
	implements ITouchObject, IInvalidating, ITrackerClient, ITactualObjectManagerClient, IValidationManagerClient/*, IDisposable*/
{	
	private static const DEG_RAD:Number = 180 / Math.PI;
	
	/**
	 * A collection of descriptors attached before the gesture module
	 * became available.
	 */
	private var _descriptorEventQueue:Array;
	
	/**
	 * A collection of activators attached to this object.
	 */
	private var _activatorPriorityQueue:DescriptorPriorityQueue;
	
	/**
	 * A collection of paths attached to this object.
	 */
	private var _pathQueue:Vector.<Path>;
	
	/**
	 * A collection of gestures attached to this object.
	 */
	private var _gesturePriorityQueue:DescriptorPriorityQueue;


	/**
	 * @private
	 */
	id_internal var descriptorCallbacks:Dictionary;

	/**
	 * @private
	 */
	id_internal var descriptorCache:Dictionary;

	/**
	 * @private
	 */
	id_internal var descriptorHistory:Dictionary;
	
	/**
	 * @private
	 */
	id_internal var dragHandlers:Dictionary;


	/**
	 * @private
	 */
	id_internal var descriptorContainer:ITouchObject;
	
	/**
	 * @private
	 */
	id_internal var tactualObjectManager:TactualObjectManager;
	
	
	protected var _blobContainerEnabled:Boolean;
	
	/**
	 * A collection of default values associated with this object.
	 */
	private var _defaults:Object =
	{
		//blobContainer: undefined,
		//blobContainerEnabled: false,
		
		topLevel: false
	}
	
    //--------------------------------------------------------------------------
    //
    //  Constructor
    //
    //--------------------------------------------------------------------------
    
    /**
     *  Constructor.
     *  
     * @langversion 3.0
     * @playerversion AIR 1.5
     * @playerversion Flash 10
     * @playerversion Flash Lite 4
     * @productversion GestureWorks 1.5
     */ 
	public function TouchObject()
	{
		super();
		
		_descriptorEventQueue = [];
		
		_activatorPriorityQueue = new DescriptorPriorityQueue();
		_gesturePriorityQueue = new DescriptorPriorityQueue();
		_pathQueue = new Vector.<Path>();

		descriptorCallbacks = new Dictionary();
		descriptorCache = new Dictionary();
		descriptorHistory = new Dictionary();
		dragHandlers = new Dictionary(true);
		
		tactualObjectManager = new TactualObjectManager();

		setParams({}, _defaults);

		addEventListener(Event.ADDED_TO_STAGE, addedToStageHandler);
		
		//CONFIG::FLASH_AUTHORING
		//{
		preinitialize();
		//}
	}
	
    //--------------------------------------------------------------------------
    //
    //  Methods: Initialization
    //
    //--------------------------------------------------------------------------
    
	/**
	 * This method is called when the default constructor has finished
	 * and before this object is attached to the stage, or its 
	 * prospective parent.  You may override this method when creating a
	 * subclass of TouchObject to ensure specific paramaters are defined
	 * and established.
     * 
	 * <p>You do not call this method directly, GestureWorks calls the
	 * <code>preinitialize()</code> method in response to object instantiation.</p>
     * 
     * <p>If publishing against the Flex SDK, this method assumes its original
     * preserved behavior and is not apart of the GestureWorks instantiation
     * cycle.</p>
	 */
	//CONFIG::FLASH_AUTHORING
	//{
	protected function preinitialize():void
	{
	}
	//}
	
	/**
	 * This method is called after the default constructor has finished
	 * and after the object is attached to the stage or its prospective
	 * parent.  You may override this method to ensure the stage exits for 
	 * child creation, or at the <code>Application</code> object level, to
	 * ensure the <code>DataManager</code> exists and has loaded the
	 * Application.xml settings.
	 * 
	 * <p>You do not call this method directly, GestureWorks calls the
	 * <code>initialize()</code> method in response to the <code>Stage</code> becoming
	 * available upon addition to another <code>DisplayObject</code>.</p>
     * 
     * <p>If publishing against the Flex SDK, this method assumes its original
     * preserved behavior and is not apart of the GestureWorks instantiation
     * cycle.</p>
	 */
	//CONFIG::FLASH_AUTHORING
	//{
	protected function initialize():void
	{
	}
	//}
	
	////////////////////////////////////////////////////////////
	// Properties: Public
	////////////////////////////////////////////////////////////
	/**
	 * Establishes the TouchObject as a blob container, which may be acted upon during
	 * blob targeting and owner selection.
	 * 
	 * <p> If set to true, the TouchObject becomes enabled for secondary blob clustering,
	 * and gesture processing and analysis. When gesture listeners are applied, if the
	 * TouchObject is transparent to target and owner selection, the respective gestures
	 * will not fire because no blobs are available for processing.  State switching is
	 * not automated as gestures are added and removed because it may interfere with
	 * the developer's programmatic intent.</p>
	 * 
	 * <p>This flag is important when considering display list structure as it defines
	 * regions, or objects, that preform secondary clustering.  Secondary clustering
	 * enables an object to capture tactual points for gesture processing, not touch
	 * processing.  Consider the following examples.</p>
	 * 
	 * @default false
	 * 
	 * @see id.core.TouchObject#drawDebug() id.core.TouchObject.drawDebug()
	 * @see id.core.TouchObjectContainer#touchChildren id.core.TouchObjectContainer.touchChildren
	 * 
	 * @includeExample BlobContainerExample.as
	 * @includeExample BlobContainerNestedExample.as
	 * 
	 * @param	value A boolean representing this object's container state.
	 */
	public function get blobContainerEnabled():Boolean { return _blobContainerEnabled; }
	public function set blobContainerEnabled(value:Boolean):void
	{
		if(value == _blobContainerEnabled)
			return;
		
		// re align the blob containers and re establish blobs appropiatly
		if(!value)
		{
			// move this blobcontainer's objects to the previous
			//set the container to the previous

			var target:ITouchObject = (parent as ITouchObject) ? (parent as ITouchObject).blobContainer : topLevelContainer ;
			
			//tactualObjectManager.migrate( target.tactualObjectManager );
			descriptorContainer = target;
			for(var idx:uint=0; idx<numChildren; idx++)
			{
				var child:ITouchObject = getChildAt(idx) as ITouchObject;
				
				if(child && !child.blobContainerEnabled)
				{
					child.blobContainer = target;
				}
			}
			
		}
		else
		{
			blobContainer = this;
		}
		
		_blobContainerEnabled = value;
	}
	
	/**
	 * @private
	 */
	public function get blobContainer():ITouchObject { return descriptorContainer; }
	
	/**
	 * @private
	 */
	public function set blobContainer(obj:ITouchObject):void {
		if(blobContainerEnabled)
			return;
			
		if(obj == descriptorContainer)
			return;

		// iterate through children
		for(var idx:uint=0; idx<numChildren; idx++)
		{
			var child:ITouchObject = getChildAt(idx) as ITouchObject;
			
			if(child && !child.blobContainerEnabled)
			{
				child.blobContainer = obj;
			}
		}
		
		/* ASSUMPTION: blob containers are not set dynamically
		descriptorCallbacks = new Dictionary();
		descriptorHistory = new Dictionary();
		
		dragHandlers = new Dictionary(true);
		//dragHandlerAdditionQueue = [];
		//dragHandlerRemovalQueue = [];
		*/
		
		descriptorContainer = obj;
	}
	
	protected var _pointTargetRediscovery:Boolean;
	
	public function get pointTargetRediscovery():Boolean
	{
		return _pointTargetRediscovery;
	}
	
	public function set pointTargetRediscovery(value:Boolean):void
	{
		if (_pointTargetRediscovery == value)
		{
			return;
		}
		
		if (value)
		{
			invalidateTactualObjects();
		}
		
		_pointTargetRediscovery = value;
	}
	
	/**
	 * @private
	 */
	public function get topLevel():Boolean { return _params.topLevel; }
	
	/**
	 * @private
	 */
	public function set topLevel(value:Boolean):void {
		if(value == topLevel)
			return;
			
		if(value)
		{
			TouchObjectGlobals.topLevelContainer.push(this);
		}
		else
		{
			// dynamic assignment??!?!
		}
		
		_params.topLevel = value;
	}
	
	/**
	 * @private
	 */
	public function get topLevelContainer():ITouchObject {
		return /*topLevel ? this : */TouchObjectGlobals.topLevelContainer[0];
	}
	
	////////////////////////////////////////////////////////////
	// Properties: Affine Transformations
	////////////////////////////////////////////////////////////
	
	protected var _affineOrigin:Point;
	protected var _affineOriginTransformed:Point;
	protected var _affineOriginStage:Point;
	
	public function get affineOrigin():Point { return _affineOrigin; }
	
	public function get affineOriginStage():Point { return _affineOriginStage; }
	
	private var currentRotation:Number;
	
	override public function set rotation(value:Number):void
	{
		if(
		   !TouchObjectGlobals.affineTransformations ||
   		   !TouchObjectGlobals.affineTransform_rotate_event ||
		   !TouchObjectGlobals.affineTransform_release_event ||
		   !descriptorContainer
		  )
		{
			super.rotation = value;
			return;
		}
		
		var event_name:String = TouchObjectGlobals.affineTransform_rotate_event;
		var historyContainer:ITouchObject = hasDescriptorHistory(event_name, true) ? this : descriptorContainer ;
		var history:Object = historyContainer.getDescriptorHistory(event_name, true);
		
		if(!history)
		{
			super.rotation = value;
			return;
		}
		
		var matrix:Matrix = transform.matrix;
		
		/*
		if(!_affineOrigin)
		{
			
			_affineOrigin = globalToLocal(history.origin_stage);
			_affineOriginTransformed = matrix.transformPoint(_affineOrigin);
			
			affinePosition = new Point(x, y);
			affineMatrixTx = matrix.tx;
			affineMatrixTy = matrix.ty;
			
			manageAffineReleaseEvents(historyContainer);
		}
		*/
		
		_affineOriginStage = history.origin_stage.clone();
		_affineOrigin = globalToLocal(_affineOriginStage);
		_affineOriginTransformed = matrix.transformPoint(_affineOrigin);
		
		applyTransformation(scaleX, scaleY, value, _affineOrigin);
	}
	
	override public function set scaleX(value:Number):void
	{
		if(
		   !TouchObjectGlobals.affineTransformations ||
   		   !TouchObjectGlobals.affineTransform_scale_event ||
		   !TouchObjectGlobals.affineTransform_release_event ||
		   !descriptorContainer
		  )
		{
			super.scaleX = value;
			return;
		}
		
		var event_name:String = TouchObjectGlobals.affineTransform_scale_event;
		var historyContainer:ITouchObject = hasDescriptorHistory(event_name, true) ? this : descriptorContainer ;
		var history:Object = historyContainer.getDescriptorHistory(event_name, true);
		
		if(!history)
		{
			super.scaleX = value;
			return;
		}
		
		var matrix:Matrix = transform.matrix;
		
		/*
		if(!_affineOrigin)
		{
			_affineOrigin = globalToLocal(history.origin_stage);
			_affineOriginTransformed = matrix.transformPoint(_affineOrigin);
			
			affinePosition = new Point(x, y);
			affineMatrixTx = matrix.tx;
			affineMatrixTy = matrix.ty;
			
			manageAffineReleaseEvents(historyContainer);
		}
		*/
		
		_affineOriginStage = history.origin_stage.clone();
		_affineOrigin = globalToLocal(_affineOriginStage);
		_affineOriginTransformed = matrix.transformPoint(_affineOrigin);
		
		applyTransformation(value, scaleY, rotation, _affineOrigin);
	}
	
	override public function set scaleY(value:Number):void
	{
		if(
		   !TouchObjectGlobals.affineTransformations ||
   		   !TouchObjectGlobals.affineTransform_scale_event ||
		   !TouchObjectGlobals.affineTransform_release_event ||
		   !descriptorContainer
		  )
		{
			super.scaleY = value;
			return;
		}
		
		var event_name:String = TouchObjectGlobals.affineTransform_scale_event;
		var historyContainer:ITouchObject = hasDescriptorHistory(event_name, true) ? this : descriptorContainer ;
		var history:Object = historyContainer.getDescriptorHistory(event_name, true);
		
		if(!history)
		{
			super.scaleY = value;
			return;
		}
		
		var matrix:Matrix = transform.matrix;
		
		/*
		if(!_affineOrigin)
		{
			
			_affineOrigin = globalToLocal(history.origin_stage);
			_affineOriginTransformed = matrix.transformPoint(_affineOrigin);
			
			affinePosition = new Point(x, y);
			affineMatrixTx = matrix.tx;
			affineMatrixTy = matrix.ty;
			
			manageAffineReleaseEvents(historyContainer);
		}
		*/
		
		_affineOriginStage = history.origin_stage.clone();
		_affineOrigin = globalToLocal(_affineOriginStage);
		_affineOriginTransformed = matrix.transformPoint(_affineOrigin);
		
		applyTransformation(scaleX, value, rotation, _affineOrigin);
	}
	
	id_internal function applyTransformation(xScale:Number, yScale:Number, r:Number, origin:Point):void
	{
		//graphics.lineStyle(2, 0xffffff, 0.75);
		//graphics.drawCircle(origin.x, origin.y, 5);
		
		var modifier:Matrix = new Matrix();
		
		modifier.tx -= origin.x;
		modifier.ty -= origin.y;
		
		modifier.scale(xScale, yScale);
		modifier.rotate(r / DEG_RAD);
		
		modifier.tx += origin.x /*+ affinePosition.x*/ - (origin.x - _affineOriginTransformed.x) /*- affineMatrixTx*/;
		modifier.ty += origin.y /*+ affinePosition.y*/ - (origin.y - _affineOriginTransformed.y) /*- affineMatrixTy*/;
		
		transform.matrix = modifier;
	}
	
	////////////////////////////////////////////////////////////
	// Drag Handlers
	////////////////////////////////////////////////////////////
	//protected var dragHandlers:Dictionary;
	//protected var dragHandlerAdditionQueue:Array;
	//protected var draghandlerRemovalQueue:Array;

	private function processDragHandlers():void
	{
		var tOs:Array;
		
		var affineOrigin:Point;
		var touchObject:ITouchObject;
		
		for(var k:* in dragHandlers)
		{
			touchObject = k as ITouchObject;
			if(!touchObject)
			{
				continue;
			}
			
			affineOrigin = touchObject.affineOriginStage;
			if(affineOrigin)
			{
				tOs = getTactualObjectsAtPosition(affineOrigin.x, affineOrigin.y);
			}
			
			if(!tOs || !tOs.length)
			{
				//tOs = getTactualObjectsByTarget(touchObject);
				tOs = _tactualTargets[touchObject] || [];
				
				var trackerO:ITactualObject = ApplicationGlobals.tracker.tactualObjects[dragHandlers[k].handle];
				if (trackerO && tOs.indexOf(trackerO) == -1)
				{
					tOs.push(trackerO);
				}
			}
			
			if(!tOs.length)
			{
				continue;
			}

			//CONFIG::DEBUG
			//{
			//import id.utils.Logger;
			//import mx.utils.ObjectUtil;
			//
			//Logger.log(this.name, "\nTouchObject::processDragHandlers -- passing:\n" + ObjectUtil.toString(tOs), Logger.NOTICE, true);
			//}

			dragHandlers[k].f.call(this, tOs);
			
			tOs = null;
			affineOrigin = null;
			touchObject = null;
		}
	}
	
	public function registerDragHandler(target:ITouchObject, f:Function, force:Boolean = false):int
	{
		if(!blobContainer)
		{
			throw new Error("Could not associate to a blob container!");
		}
		
		if(blobContainer != this)
		{
			return blobContainer.registerDragHandler(target, f);
		}
		
		var handle:int;
		var parent:ITouchObject = parent as ITouchObject;

		var history:Object = descriptorHistory[TouchEvent.TOUCH_DOWN];
		if(!history && parent)
		{
			return parent.registerDragHandler(target, f);
		}
		
		var found:Boolean;
		for(var k:* in dragHandlers)
		{
			if(k == target)
			{
				found = true;
				break;
			}
		}
		
		if(found && !force)
		{
			return -1;
		}
		
		handle = history ? history.id : int.MAX_VALUE ;
		dragHandlers[target] = {handle: handle, f: f};
		
		return handle;
	}
	
	public function unregisterDragHandler(target:ITouchObject, f:Function, force:Boolean = false):int
	{
		if(!blobContainer)
		{
			throw new Error("Could not associate to a blob container!");
		}

		if(blobContainer != this)
		{
			return blobContainer.unregisterDragHandler(target, f);
		}
		
		var found:Object;
		var parent:ITouchObject = parent as ITouchObject;
		
		for(var k:* in dragHandlers)
		{
			if(k == target)
			{
				found = dragHandlers[target];
				break;
			}
		}

		if(!found || found.f != f)
		{
			if(parent)
			{
				return parent.unregisterDragHandler(target, f);				
			}
			else
			{
				throw new Error("Could not find the drag handler!");
			}
		}
		
		var count:uint = 0;
		var tO:ITactualObject;
		
		if(_tactualTargets)
		for each(tO in _tactualTargets[target])
		{
			if(tO.state != TactualObjectState.REMOVED)
			{
				count++;
			}
		}
		
		var handle:int = found.handle;
		var tracker:ITracker = ApplicationGlobals.tracker;
		
		if (tracker)
		if (handle != int.MAX_VALUE)
		{
			tO = tracker.tactualObjects[handle];
			if(tO && tO.state != TactualObjectState.REMOVED)
			{
				count++
			}
		}
		
		if(count && !force)
		{
			return -1;
		}
		
		dragHandlers[target] = null;
		delete dragHandlers[target];
		
		return handle;
	}
	
	
	/*
	private function manageAffineReleaseEvents(touchObject:ITouchObject):void
	{
		if(_affineHistoryObjects.hasOwnProperty(touchObject))
		{
			return;
		}
		
		_affineHistoryObjects[touchObject] = touchObject;
		touchObject.addEventListener(TouchObjectGlobals.affineTransform_release_event, affineReleaseHandler, false, 0, true);
	}
	
	private function affineReleaseHandler(event:Event):void
	{
		if(!event.hasOwnProperty("name"))
		{
			return;
		}
		
		var event_name:String = event["name"];
		if (event_name == TouchObjectGlobals.affineTransform_rotate_event)
		{
			//affineRotationPt = null;
			_affineOrigin = null;
		}
		else
		if (event_name == TouchObjectGlobals.affineTransform_scale_event)
		{
			//affineScalePt = null;
			_affineOrigin = null;
		}
	}
	*/
	
	////////////////////////////////////////////////////////////
	// Methods: Event Attachment
	////////////////////////////////////////////////////////////
	/**
     * @private
     * @copy flash.events.EventDispatcher#addEventListener
	 */
	override public function addEventListener(type:String, listener:Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false):void
	{
		if(!ApplicationGlobals.descriptorModule)
		{
			// queue it
			//trace("Gesture library is not defined!  Please define it before attaching listeners!" + "\n" + this + "\n" + type + "\n" + listener);
		}
		
		if(!hasEventListener(type))
		{
			attachDescriptor(type);
		}
		
		super.addEventListener(type, listener, useCapture, priority, useWeakReference);
	}
	
	/**
     * @private
     * @copy flash.events.EventDispatcher#removeEventListener
	 */
	override public function removeEventListener(type:String, listener:Function, useCapture:Boolean = false):void
	{
		super.removeEventListener(type, listener, useCapture);
		
		if(!hasEventListener(type))
		{
			removeDescriptor(type);
		}
	}
	
	private function attachDescriptor(type:String):void
	{
		//var descriptor:IDescriptor = getDescriptorFromType(type);
		var descriptor:Object = getDescriptorFromType(type);
		if(!descriptor || descriptor as ITouch)
		{
			return;
		}
		
		if(descriptor is Path)
		{
			_pathQueue.push(descriptor);
		}
		else
		if(descriptor as IGesture)
		{
			//_gesturePriorityQueue.addDescriptor(descriptor);
			_gesturePriorityQueue.addDescriptor(descriptor as IDescriptor);
		}
	}
	
	private function removeDescriptor(type:String):void
	{
		//var descriptor:IDescriptor = getDescriptorFromType(type);
		var descriptor:Object = getDescriptorFromType(type);
		if(!descriptor || descriptor as ITouch)
		{
			return;
		}
		
		if(descriptor is Path)
		{
			_pathQueue.splice(_pathQueue.indexOf(descriptor), 1);
		}
		else
		if(descriptor as IGesture)
		{
			//_gesturePriorityQueue.removeDescriptor(descriptor);
			_gesturePriorityQueue.removeDescriptor(descriptor as IDescriptor);
		}
	}
	
	/*
		TODO: Optimize this method. Should not have to iterate through
		objects to find the type.  Set up a hash map of sorts keyed to the
		descriptor name. ??? wtf was I thinking
	*/
	//private function getDescriptorFromType(type:String):IDescriptor
	private function getDescriptorFromType(type:String):Object
	{
		var descriptorList:Object = ApplicationGlobals.descriptorList;
		
		for(var k:String in descriptorList)
		for(var j:String in descriptorList[k])
		{
			if(j != type)
				continue;
			
			return descriptorList[k][j];
		}
		
		return null;
	}
	
	////////////////////////////////////////////////////////////
	// Methods: Event Utilities
	////////////////////////////////////////////////////////////
    
    /**
     * @private
     * 
     * @param target
     * @param event
     */
	id_internal static function dispatchMouseHack(target:DisplayObject, event:TouchEvent):void
	{
		var ret_event:Event = EventUtil.degradateTouchEvent(event, ApplicationGlobals.descriptorAssembly);
		if(!ret_event)
		{
			return;
		}
		
		target.dispatchEvent(ret_event);
	}
	
	////////////////////////////////////////////////////////////
	// Methods: Descriptor Processing
	////////////////////////////////////////////////////////////
	private var _disables:Array;
	private var _tactualClusters:Vector.<ITactualObject>;
	private var _tactualObjects:Vector.<ITactualObject>;
	private var _tactualObjectsUnclustered:Vector.<ITactualObject>;
	private var _tactualTargets:Dictionary;
	
	private function processDescriptors():void
	{
		//trace("\nProcessing on:", ApplicationGlobals.application.currentFrame, tactualObjectManager.tactualObjects.length);
				
		_disables = [];
		_tactualClusters = tactualObjectManager.tactualClusters;
		_tactualObjects = tactualObjectManager.tactualObjects;
		
		if(!_tactualObjects.length)
		{
			return;
		}
		
		_tactualObjectsUnclustered = new Vector.<ITactualObject>();
		
		var tC:ICluster;
		var tO:ITactualObject;
		var found:Boolean;
		
		for each(tO in _tactualObjects)
		{
			found = false;
			for each(tC in _tactualClusters)
			{
				if(tC.hasTactualObject(tO))
				{
					found = true;
					break;
				}
			}
			
			if(!found)
			{
				_tactualObjectsUnclustered.push(tO);
			}
		}
		
		_tactualTargets = new Dictionary(true);
		
		var target:DisplayObject;
		for each(tO in _tactualObjects)
		{
			target = tO.target;
			
			if(!_tactualTargets[tO.target])
				_tactualTargets[tO.target] = [];
			
			_tactualTargets[tO.target].push(tO);
		}
				
		processActivators();
		processPaths();
		processGestures();
		
		processTouch();
		
		processDragHandlers();
		
		for(var k:String in _tactualTargets)
		{
			delete _tactualTargets[k];
		}
		
		_tactualTargets = null;
		
		_affineOriginStage = null;
		_affineOrigin = null;
		_affineOriginTransformed = null;
		
		_disables = null;
		
		_tactualClusters = null;
		_tactualObjects = null;
		_tactualObjectsUnclustered = null;
	}
	
	private function processActivators():void
	{
		var descriptor:IDescriptor;
		var descriptor_result:Object;
		
		var event:*;
		var event_name:String;
		
		while(_activatorPriorityQueue.hasNext())
		{
			descriptor = _gesturePriorityQueue.next;
			event_name = ApplicationGlobals.descriptorMap[descriptor.name];
			
			event = new TouchObjectGlobals.activatorEvent();
		}
	}
	
	private function processPaths():void
	{
		if
		(
			_pathQueue.length == 0 ||
			_tactualObjects.length != 1
		)
		{
			return;
		}
		
		var tO:ITactualObject = _tactualObjects[0];
		
		if (tO.state == TactualObjectState.ADDED)
		{
			_disables.push(TouchEvent.TOUCH_DOWN);
		}
		
		if (tO.state != TactualObjectState.REMOVED)
		{
			return;
		}
		
		var results:Object = PathProcessor.CompareRawToNormalizedPathCollection(tO, _pathQueue);
		if(!results)
		{
			return;
		}
		
		var event:*;
		var event_class:Class = results.path.eventClass;
		var event_name:String = results.path.name;
		
		event = new event_class(event_name, false, false);
		event.matchValue = results.score;
		
		dispatchEvent(event);
	}
	
	/*
	private function processPaths():void
	{
		if(!_pathQueue.length)
		{
			return;
		}
		
		if(_tactualObjects.length != 1)
		{
			return;
		}
		
		//if(!TouchObjectGlobals.pathEvents)
		//{
		//	return;
		//}
		
		var tO:ITactualObject = _tactualObjects[0];
		
		if (tO.state == TactualObjectState.ADDED)
		{
			_disables.push(TouchEvent.TOUCH_DOWN);
		}
		
		if (tO.state != TactualObjectState.REMOVED)
		{
			return;
		}
		
		trace("\nProcessing paths");
		
		var idx:int;
		var item:Object;
		var tO_history:Vector.<Object> = tO.combinedHistory;
		
		var pathCollection:PathCollection = new PathCollection();
		
		for(idx=0; idx<tO_history.length; idx++)
		{
			item = tO_history[idx];
			
			pathCollection.addPoint(item.x, item.y);
			// pathCollection.collection_x.push(item.x);
			// pathCollection.collection_y.push(item.y);
		}
		
		// pathCollection.size = tO_history.length;
		
		
		// debug stuff
		// var app:Application = ApplicationGlobals.application as Application;
		
		//app.graphics.clear();
		//app.graphics.lineStyle(5, 0xffffff, 1.0, true);
		//app.graphics.moveTo(tO_history[0].x, tO_history[0].y);
		
		//for(idx=1; idx<tO_history.length; idx++)
		//{
		//	app.graphics.lineTo(tO_history[idx].x, tO_history[idx].y);
		//}
		
		//app.graphics.lineStyle(3, 0x9999ff, 0.8, true);
		//app.graphics.moveTo(pathCollection.collection_x[0], pathCollection.collection_y[0]);
		
		//for(idx=1; idx<pathCollection.length; idx++)
		//{
		//	app.graphics.lineTo(pathCollection.collection_x[idx], pathCollection.collection_y[idx]);
		//}
		
		
		
	
		
		var pc:PathCollection;		
		var ret:Number;
		
		var best:Number = 1.0;
		var bestPc:PathCollection;
		
		for(idx=0; idx<_pathQueue.length; idx++)
		{
			pc = _pathQueue[idx];
			
			//pt.scale(pathCollection.width > pathCollection.height ? pathCollection.width : pathCollection.height);
			
			//ret = pt.compareTo(pathCollection);
			ret = PathProcessor.CompareRawToNormalizedPath(tO, pc);
			if(ret == Number.NEGATIVE_INFINITY || ret > 1.0)
			{
				continue;
			}
			
			trace(pc.name, ret);
			
			if(ret < best)
			{
				best = ret;
				bestPc = pc;
			}
		}
		
		if(!bestPc)
		{
			return;
		}
		
		//var events:Array = TouchObjectGlobals.pathEvents;
		var event:*;
		
		var event_class:Class = bestPc.eventClass;
		var event_name:String = bestPc.name;
		
		event = new event_class(event_name, false, false);
		dispatchEvent(event);
	}
	*/
	
	private function processGestures():void
	{
		var descriptor:IDescriptor;
		var descriptor_result:Object;
		
		var event:*;
		var event_name:String;
		
		var tOs:Array;
		var tO:ITactualObject;
		
		var pt:Point;
		
		var filter_result:Boolean;
		var idx:uint;
		
		var event_class:Class = TouchObjectGlobals.gestureEvent;
		
		while(_gesturePriorityQueue.hasNext())
		{				
			descriptor = _gesturePriorityQueue.next;
			event_name = ApplicationGlobals.descriptorMap[descriptor.name];
			
			// filter::disables
			if(_disables.indexOf(event_name) != -1)
			{
				//trace(event_name, "failed @ disables");
				processDescriptorRelease(event_name, event_class);
				continue;
			}
			
			tOs = getTactualObjects(descriptor);
			
			// filter::objCount
			if(!tOs)
			{
				//trace(event_name, "failed @ objCount");
				processDescriptorRelease(event_name, event_class);
				continue;
			}
			
			// filter::objState
			filter_result = true;
			for(idx=0; idx<tOs.length; idx++)
			{
				tO = tOs[idx];
				if(tO.type != TactualObjectType.POINT)
				{
					continue;
				}
				
				if((tO.state & descriptor.objState) == 0)
				{
					filter_result = false;
					break;
				}
			}
			
			if(!filter_result)
			{
				//trace(event_name, "failed @ objState");
				processDescriptorRelease(event_name, event_class);
				continue;				
			}
			
			
			// filter::objHistoryCount
			filter_result = true;
			for(idx=0; idx<tOs.length; idx++)
			{
				tO = tOs[idx];
				if(tO.history.length < descriptor.objHistoryCount)
				{
					filter_result = false;
					break;
				}
			}
			
			if(!filter_result)
			{
				//trace(event_name, "failed @ objHistoryCount");
				processDescriptorRelease(event_name, event_class);
				continue;
			}
			
			descriptor.cache = getDescriptorCache(event_name);
			descriptor.history = getDescriptorHistory(event_name);
			
			descriptor_result = descriptor.process.apply(this, tOs);
			if(!descriptor_result)
			{
				//trace(event_name, "failed @ descriptor_result");
				
				/*
				if(!processDescriptorRelease(event_name, event_class))
				{
					addDescriptorCache(event_name, descriptor.cache);
				}
				*/
				
				addDescriptorCache(event_name, descriptor.cache);
				processDescriptorRelease(event_name, event_class);
				
				continue;
			}
			descriptor_result.timeStamp = getTimer();
			
			// translate point for localX and localY
			pt = globalToLocal(descriptor.referencePoint);
			
			// attach descriptor origin
			//descriptor_result.localX = pt.x;
			//descriptor_result.localY = pt.y;
			//descriptor_result.origin_local = pt;
			descriptor_result.origin_stage = descriptor.referencePoint;
			
			// establish disables
			_disables = _disables.concat(descriptor.disables);
			
			// establish history
			addDescriptorCache(event_name, descriptor.cache);
			addDescriptorHistory(event_name, descriptor_result);
			
			event = new event_class(event_name, false, false, pt.x, pt.y, descriptor.referencePoint.x, descriptor.referencePoint.y, this, tOs);
			for(var k:String in descriptor_result)
			{
				event[k] = descriptor_result[k];
			}
						
			dispatchEvent(event);
		}
		
		_gesturePriorityQueue.reset();
	}
	
	private function processTouch():void
	{
		var descriptor:IDescriptor;
		var descriptor_result:Object;
		
		var dispatch:Boolean;
		var dispatch_e:String;
		var dispatch_o:DisplayObject;
		
		var event:TouchEvent;
		var event_name:String;
		var event_target:DisplayObject;
		
		var idx:uint;
		var p:DisplayObject;
		
		var pt:Point;
		var tO:ITactualObject;
		
		while(ApplicationGlobals.descriptorPriorityQueue.hasNext())
		{
			descriptor = ApplicationGlobals.descriptorPriorityQueue.next;
			event_name = ApplicationGlobals.descriptorMap[descriptor.name];

			// filter::disables
			if(_disables.indexOf(event_name) != -1)
				continue;

			for(idx=0; idx<_tactualObjects.length; idx++)
			{				
				tO = _tactualObjects[idx];
				
				// filter::objState
				if((tO.state & descriptor.objState) == 0)
					continue;
				
				// filter::objHistoryCount
				if(tO.history.length < descriptor.objHistoryCount)
					continue;
				
				/*if(dispatch_e != event_name || dispatch_o != tO.target)
				{
					dispatch = false;
					
					for(p = tO.target; p!=null; p=p.parent)
					if (p.hasEventListener(event_name))
					{
						dispatch = true;
						break;
					}
					
					dispatch_e = event_name;
					dispatch_o = tO.target;
				}*/
				
				/*if(!dispatch)
				{
					continue;
				}*/
				
				descriptor_result = descriptor.process.call(this, tO);
				
				if(!descriptor_result)
				{
					continue;
				}
				
				descriptor_result.id = tO.id;
				descriptor_result.timeStamp = getTimer();
				
				// establish history
				addDescriptorHistory(event_name, descriptor_result);
				
				pt = tO.target.globalToLocal(new Point(tO.x, tO.y));

				//event = new TouchEvent(event_name, true, true, pt.x, pt.y, tO.x, tO.y, this, tO);//ApplicationGlobals.tracker.tactualObjects[tO.id]);
				event = new TouchEvent(event_name, true, true, tO.id, false, pt.x, pt.y, tO.width, tO.height, tO.pressure, this);
				event._tactualObject = tO;
				event._stageX = tO.x;
				event._stageY = tO.y;
				
				for(var k:String in descriptor_result)
				{
					event[k] = descriptor_result[k];
				}
				
				event_target = descriptor.eventTarget || tO.target ;
				descriptor.eventTarget = null;
				
				if(dispatch_e != event_name || dispatch_o != event_target)
				{
					dispatch = false;
					
					for(p = event_target; p!=null; p=p.parent)
					if (p.hasEventListener(event_name))
					{
						dispatch = true;
						break;
					}
					
					dispatch_e = event_name;
					dispatch_o = tO.target;
				}
								
				processDescriptorCallbacks(event_name, event);
				
				if(TouchObjectGlobals.degradeTouchEvents)
				//!CONFIG::FLASH_AUTHORING
				{
					dispatchMouseHack(tO.target, event);
				}
				
				if(!dispatch)
				{
					continue;
				}
				
				event_target.dispatchEvent(event);
			}
		}
		
		if(pointTargetRediscovery)
		{
			for(idx=0; idx<_tactualObjects.length; idx++)
			{
				_tactualObjects[idx].hasNewTarget = false;
			}
		}
		
		clearTouchHistory();
		ApplicationGlobals.descriptorPriorityQueue.reset();
	}
	
	private function getTactualObjects(descriptor:IDescriptor):Array
	{
		var n_tC:int = _tactualClusters.length;
		var n_tO:int = _tactualObjects.length;
		var n_tU:int = _tactualObjectsUnclustered.length;

		// determine object availability
		/*if(
		   (descriptor.objType == (TactualObjectType.CLUSTER | TactualObjectType.POINT) && descriptor.objCount > n_tC + n_tO) ||
		   (descriptor.objType == TactualObjectType.CLUSTER && descriptor.objCount > n_tC) ||
		   (descriptor.objType == TactualObjectType.POINT && descriptor.objCount > n_tO))
		{
			return null;
		}*/
		
		var tOs:Array = [];
		var tO_req:int = descriptor.objCount;
		var tO_req_min:int = descriptor.objCountMin;
		var tO_req_max:int = descriptor.objCountMax;
		
		var idx:uint;
		var n:uint;

		if(tO_req > n_tO || tO_req_min > n_tO)
		{
			return null;
		}

		//if(descriptor.objType | (
		if(descriptor.objType == (TactualObjectType.CLUSTER | TactualObjectType.POINT))
		{
			if (tO_req_min < tO_req_max)
			{
				tO_req = Math.max(tO_req_min, Math.min(n_tC + n_tU, tO_req_max));
			}
			
			/*
			tO_req = tO_req_min < tO_req_max ?
				Math.max(tO_req_min, Math.min(n_tC + n_tU, tO_req_max)) :
				tO_req
			;
			*/
			
			//if(descriptor.objCount <= n_tC + n_tU)
			if (tO_req <= n_tC + n_tU)
			{
				//tOs = tOs.concat(_tactualClusters.slice(0, tO_req > _tactualClusters.length ? _tactualClusters.length : tO_req));
				n = tO_req > _tactualClusters.length ? _tactualClusters.length : tO_req ;
				for(idx=0; idx<n; idx++)
				{
					tOs.push(_tactualClusters[idx]);
				}
	
				n = tO_req - tOs.length;
				for(idx=0; idx<n; idx++)
				{
					tOs.push(_tactualObjectsUnclustered[idx]);
				}
			}
			else
			{
				for(idx=0; idx<tO_req; idx++)
				{
					tOs.push(_tactualObjects[idx]);
				}
			}
		}
		else
		if(descriptor.objType == TactualObjectType.CLUSTER)
		{
			if (tO_req_min < tO_req_max)
			{
				tO_req = Math.max(tO_req_min, Math.min(n_tC, tO_req_max));
			}
			
			//if(descriptor.objCount > n_tC)
			if (tO_req > n_tC)
			{
				return null;
			}
			
			for(idx=0; idx<tO_req; idx++)
			{
				tOs.push(_tactualClusters[idx]);
			}
		}
		else
		if(descriptor.objType == TactualObjectType.POINT)
		{
			if (tO_req_min < tO_req_max)
			{
				tO_req = Math.max(tO_req_min, Math.min(n_tO, tO_req_max));
			}
			
			  //tO_req = Math.max(tO_req, tO_req_min, Math.min(n_tO, tO_req_max));
			
			for(idx=0; idx<tO_req; idx++)
			{
				tOs.push(_tactualObjects[idx]);
			}
		}
		
		return tOs;
	}
	
	private function getTactualObjectsAtPosition(xPos:Number, yPos:Number):Array
	{
		var tO:ITactualObject;
		var tOs:Array = [];

		for each(tO in _tactualClusters)
		{
			if(tO.x != xPos || tO.y != yPos)
			{
				continue;
			}
			
			tOs.push(tO);
		}

		if(!tOs.length)
		for each(tO in _tactualObjects)
		{
			if(tO.x != xPos || tO.y != yPos)
			{
				continue;
			}
			
			tOs.push(tO);
		}
		
		return tOs;
	}
	
	private function getTactualObjectsByTarget(target:ITouchObject):Array
	{
		var tO:ITactualObject;
		var tOs:Array = [];

		var displayObject:DisplayObject = target as DisplayObject;

		for each(tO in _tactualObjects)
		{
			if(tO.target != displayObject)
			{
				continue;
			}
			
			tOs.push(tO);
		}
		
		return tOs;
	}
	
	private function processDescriptorRelease(descriptor:String, descriptorEvent:Class):void
	{
		if(!descriptorHistory.hasOwnProperty(descriptor))
		{
			return;
		}
		
		var history:Object = descriptorHistory[descriptor];
		
		// this should be done in the processor
		/*if (getTimer() - history.timeStamp > 200)
		{
			removeDescriptorHistory(descriptor);
			return;
		}*/

		if(!descriptorEvent.hasOwnProperty("RELEASE"))
		{
			removeDescriptorHistory(descriptor);
			return;
		}
		
		var event:* = new descriptorEvent(descriptorEvent.RELEASE, false, false);
		for(var k:String in history)
		{
			event[k] = history[k];
		}
		event.name = descriptor;
		
		removeDescriptorHistory(descriptor);
		dispatchEvent(event);
	}

	////////////////////////////////////////////////////////////
	// Methods: Descriptor Hooks
	////////////////////////////////////////////////////////////
	private function processDescriptorCallbacks(descriptor:String, descriptor_event:*):void
	{
		if(!descriptorCallbacks.hasOwnProperty(descriptor))
			return;
		
		var list:Array = descriptorCallbacks[descriptor];
		for each(var f:Function in list)
		{
			f(descriptor_event);
		}
	}
	
	id_internal function registerDescriptorCallback(descriptor:String, f:Function):void
	{
		if(!descriptorCallbacks.hasOwnProperty(descriptor))
			descriptorCallbacks[descriptor] = [];
		
		var index:int = descriptorCallbacks[descriptor].indexOf(f);
		if (index != -1)
			return;
		
		descriptorCallbacks[descriptor].push(f);
	}
	
	id_internal function unregisterDescriptorCallback(descriptor:String, f:Function):void
	{
		if(!descriptorCallbacks.hasOwnProperty(descriptor))
			return;
		
		var index:int = descriptorCallbacks[descriptor].indexOf(f);
		if (index == -1)
			return;
		
		descriptorCallbacks[descriptor].splice(index, 1);
		if(!descriptorCallbacks[descriptor].length)
		{
			descriptorCallbacks[descriptor] = null;
			delete descriptorCallbacks[descriptor];
		}
	}

	////////////////////////////////////////////////////////////
	// Methods: Descriptor Cache
	////////////////////////////////////////////////////////////
	id_internal function addDescriptorCache(descriptor:String, descriptor_cache:Object):void
	{
		descriptorCache[descriptor] = descriptor_cache;
	}
	
	id_internal function removeDescriptorCache(descriptor:String):void
	{
		if(!descriptorCache.hasOwnProperty(descriptor))
		{
			return;
		}
		
		descriptorCache[descriptor] = null;
		delete descriptorCache[descriptor];
	}
	
	id_internal function clearDescriptorCache():void
	{
		// stub
	}
	
	id_internal function getDescriptorCache(descriptor:String):Object
	{
		if(!descriptorCache.hasOwnProperty(descriptor))
		{
			return null;
		}
		
		return descriptorCache[descriptor];
	}

	////////////////////////////////////////////////////////////
	// Methods: Descriptor History
	////////////////////////////////////////////////////////////
	id_internal function addDescriptorHistory(descriptor:String, descriptor_result:Object):void
	{
		/*if(!descriptorHistory.hasOwnProperty(descriptor))
		{
			return;
		}*/
		
		descriptorHistory[descriptor] = descriptor_result;
	}
	
	id_internal function removeDescriptorHistory(descriptor:String):void
	{
		if(!descriptorHistory.hasOwnProperty(descriptor))
		{
			return;
		}

		descriptorHistory[descriptor] = null;
		delete descriptorHistory[descriptor];
	}
	
	id_internal function clearTouchHistory():void
	{
		var descriptorList:Object = ApplicationGlobals.descriptorList;
		for(var k:String in descriptorList[DescriptorAssembly.TOUCHES])
		{
			removeDescriptorHistory(k);
		}
	}
	
	public function getDescriptorHistory(descriptor:String, partial:Boolean = false):Object
	{
		var ret:Object;
		
		if(partial)
		{
			var k:String;
			for(k in descriptorHistory)
			{
				if(k.indexOf(descriptor) == -1)
				{
					continue;
				}
				
				ret = descriptorHistory[k];
				break;
			}
		}
		else
		if(!descriptorHistory.hasOwnProperty(descriptor))
		{
			ret = null;
		}
		else
		{
			ret = descriptorHistory[descriptor];
		}
			
		return ret;
	}
	
	public function hasDescriptorHistory(descriptor:String, partial:Boolean = false):Boolean
	{
		var ret:Boolean;
		
		if(partial)
		{
			var k:String;
			for(k in descriptorHistory)
			{
				if(k.indexOf(descriptor) == -1)
				{
					continue;
				}
				
				ret = true;
				break;
			}
		}
		else
		{
			ret = descriptorHistory.hasOwnProperty(descriptor);
		}
		
		return ret;
	}

	////////////////////////////////////////////////////////////
	// Methods: Public
	////////////////////////////////////////////////////////////
	public function discoverTactualObjectContainer():void
	{
		var dO:DisplayObject;
		var dC:ITouchObject;
		
		for(dO=parent; dO!=null; dO=dO.parent)
		{
			dC = dO as ITouchObject;
			if(!dC)
			{
				continue;
			}

			if(!dC.blobContainer)
			{
				dC.discoverTactualObjectContainer();
			}
			
			blobContainer = dC.blobContainer;
			return;
		}
		
		throw new Error(
			"Tactual object container discovery failed! " +
			"Please define atleast one top most id.core::Application level object!"
		);
	}

	////////////////////////////////////////////////////////////
	// Methods: Preserved
	////////////////////////////////////////////////////////////
	id_internal final function get $rotation():Number { return super.rotation; }
	id_internal final function set $rotation(value:Number):void
	{
		super.rotation = value;
	}
	
	id_internal final function get $scaleX():Number { return super.scaleX; }
	id_internal final function set $scaleX(value:Number):void
	{
		super.scaleX = value;
	}
	
	id_internal final function get $scaleY():Number { return super.scaleY; }
	id_internal final function set $scaleY(value:Number):void
	{
		super.scaleY = value;
	}
	
	
	
	protected function get $_rotation():Number { return super.rotation; }
	protected function set $_rotation(value:Number):void
	{
		super.rotation = value;
	}
	
	protected function get $_scaleX():Number { return super.scaleX; }
	protected function set $_scaleX(value:Number):void
	{
		super.scaleX = value;
	}
	
	protected function get $_scaleY():Number { return super.scaleY; }
	protected function set $_scaleY(value:Number):void
	{
		super.scaleY = value;
	}

	////////////////////////////////////////////////////////////
	// Methods: Event Handlers
	////////////////////////////////////////////////////////////
	/**
	 * @private
	 * 
	 * @param	event
	 */
	id_internal function addedToStageHandler(event:Event):void
	{
		removeEventListener(Event.ADDED_TO_STAGE, addedToStageHandler);
		
		//CONFIG::FLASH_AUTHORING
		//{
		initialize();
		//}
	}

	////////////////////////////////////////////////////////////
	// Methods: IInvalidating
	////////////////////////////////////////////////////////////
    
	private var invalidateTactualObjectsFlag:Boolean = false;

    /**
     * 
     */
	public function invalidateTactualObjects():void
	{
		if(invalidateTactualObjectsFlag)
			return;
		
		invalidateTactualObjectsFlag = true;
		ApplicationGlobals.validationManager.invalidateClient(this);
	}
	
	/*
	public function validateNow():void
	{
		invalidateTactualObjectsFlag = false;
		ApplicationGlobals.validationManager.validateClient(this);
	}
	*/

	////////////////////////////////////////////////////////////
	// Methods: IValidationManagerClient
	////////////////////////////////////////////////////////////
    
	public function validateTactualObjects():void
	{
		tactualObjectManager.validateTactualObjects();
		processDescriptors();
		
		invalidateTactualObjectsFlag = false;
	}

	////////////////////////////////////////////////////////////
	// Methods: ITrackerClient
	////////////////////////////////////////////////////////////
	
	////////////////////////////////////////////////////////////
	// Methods: ITactualObjectManagerClient
	////////////////////////////////////////////////////////////
	public function addTactualObject(tO:ITactualObject):void
	{
		tactualObjectManager.addTactualObject(tO);
		invalidateTactualObjects();
	}
	
	public function removeTactualObject(tO:ITactualObject):void
	{
		tactualObjectManager.removeTactualObject(tO);
		invalidateTactualObjects();
	}
	
}
	
}
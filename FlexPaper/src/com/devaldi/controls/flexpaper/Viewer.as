/* 
Copyright 2009 Erik Engström

This file is part of FlexPaper.

FlexPaper is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

FlexPaper is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with FlexPaper.  If not, see <http://www.gnu.org/licenses/>.	
*/
	
package com.devaldi.controls.flexpaper
{
	import caurina.transitions.Tweener;
	
	import com.devaldi.controls.FlowBox;
	import com.devaldi.controls.ZoomCanvas;
	import com.devaldi.streaming.DupImage;
	import com.devaldi.streaming.DupLoader;
	import com.devaldi.streaming.ForcibleLoader;
	
	import flash.display.DisplayObject;
	import flash.display.Loader;
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.filters.DropShadowFilter;
	import flash.net.URLRequest;
	import flash.printing.PrintJob;
	import flash.text.TextSnapshot;
	import flash.ui.Keyboard;
	
	import mx.containers.Canvas;
	import mx.controls.Image;
	import mx.core.Container;
	import mx.core.UIComponent;
	import mx.events.FlexEvent;
	
 
	[Event(name="onPapersLoaded", type="flash.events.Event")]
	[Event(name="onPapersLoading", type="flash.events.Event")]
	[Event(name="onNoMoreSearchResults", type="flash.events.Event")]
	
	public class Viewer extends Canvas
	{
		private var _swfFile:String = "";
		private var _swfFileChanged:Boolean = false;
		private var _initialized:Boolean = false;
		private var _loader:Loader = new Loader();
		private var _libMC:MovieClip = new MovieClip();
		private var _displayContainer:Container;
		private var _paperContainer:ZoomCanvas;
		private var _swfContainer:Canvas; 
		private var _scale:Number = 1;
		private var _pscale:Number = 1;
		private var _swfLoaded:Boolean  = false;
		private var _pageList:Array;
		private var _viewMode:String = "Portrait"; 
		private var _scrollToPage:Number = 0;
		private var _numPages:Number = 0;
		private var _currPage:Number = 1;
		private var _tweencount:Number = 0;
		private var _bbusyloading:Boolean = true;
		private var _loaderList:Array;
		
		public function Viewer(){
			super();
		}

		[Bindable]
		public function get ViewMode():String {
		    return _viewMode;
		}	
		
		public function set ViewMode(s:String):void {
			if(s!=_viewMode){
				_viewMode = s;
				if(_viewMode == "Tile"){_pscale = _scale; _scale = 0.23;_paperContainer.verticalScrollPosition = 0;}else{_scale = _pscale;}
				if(_initialized && _swfLoaded){createDisplayContainer();repaint();}
			}
		}

		[Bindable]
		public function get numPages():Number {
		    return _numPages;
		}	
		
		private function set numPages(n:Number):void {
			_numPages = n;
		}
		

		[Bindable]
		public function get currPage():Number {
		    return _currPage;
		}	
		
		private function set currPage(n:Number):void {
			_currPage = n;
		}		
		
		public function gotoPage(p:Number):void{
			if(p<1 || p-1 >_pageList.length)
				return;
			else{
				_paperContainer.verticalScrollPosition = _pageList[p-1].y;
				repositionPapers();
			}
		}
		
		public function switchMode():void{
			if(ViewMode == "Portrait"){ViewMode = "Tile";}
			else if(ViewMode == "Tile"){_scale = _pscale; ViewMode = "Portrait";}
		}
		
		public function get SwfFile():String {
		    return _swfFile;
		}	
		
		public function set SwfFile(s:String):void {
			_swfFile = s;
			_swfFileChanged = true;
			
			// Changing the SWF file causes the component to invalidate.
			invalidateProperties();
 			invalidateSize();
            invalidateDisplayList();			 
		}
		
		public function get Scale():String {
		    return _scale.toString();
		}				
	
		public function Zoom(factor:Number):void{
			if(factor<0.10 || factor>5)
				return;
			
			if(_viewMode != "Portrait"){return;}
			
			var _target:DisplayObject;
			_paperContainer.CenteringEnabled = true;
			
			if(_viewMode == "Tile"){// works but buggy, needs more work.
				var im:Image;
				
				for(var ti:int=0;ti<_displayContainer.numChildren;ti++){
					_target = _displayContainer.getChildAt(ti);
					for(var ii:int=0;ii< (_target as mx.containers.Box).numChildren;ii++){			
						im = (_target as mx.containers.Box).getChildAt(ii) as Image;
						Tweener.addTween(im, {scaleX: factor, scaleY: factor, time: 0, transition: 'easeOut', onComplete: tweenComplete});
					}					
				}
			}else{								
				_tweencount = _displayContainer.numChildren;
				
				for(var i:int=0;i<_displayContainer.numChildren;i++){
					_target = _displayContainer.getChildAt(i);
					_target.filters = null;
					Tweener.addTween(_target, {scaleX: factor, scaleY: factor, time: 0.6, transition: 'easeOut', onComplete: tweenComplete});
				}
			}
		}
		
		public function fitWidth():void{
			if(_displayContainer.numChildren == 0){return;}
			
			var _target:DisplayObject;
			_paperContainer.CenteringEnabled = true;
			var factor:Number = (_paperContainer.width / _loader.width) - 0.031; //- 0.03; 
			
			for(var i:int=0;i<_displayContainer.numChildren;i++){
				_target = _displayContainer.getChildAt(i);
				_target.filters = null;
				Tweener.addTween(_target, {scaleX:factor, scaleY:factor,time: 0, transition: 'easeOut', onComplete: tweenComplete});
			}			
		}
		
		public function fitHeight():void{
			if(_displayContainer.numChildren == 0){return;}
			
			var _target:DisplayObject;
			_paperContainer.CenteringEnabled = true;
			var factor:Number = (_paperContainer.height / _loader.height); 
			
			for(var i:int=0;i<_displayContainer.numChildren;i++){
				_target = _displayContainer.getChildAt(i);
				_target.filters = null;
				Tweener.addTween(_target, {scaleX:factor, scaleY:factor,time: 0, transition: 'easeOut', onComplete: tweenComplete});
			}					
		}
		
		private function tweenComplete():void{
			_tweencount--;
			if(_tweencount==0){
				_paperContainer.dispatchEvent(new FlexEvent(FlexEvent.UPDATE_COMPLETE));
			}
		}
		
		public function set Scale(s:String):void {
			var diff:Number = _scale - new Number(s);
			_scale = new Number(s);
		}		
				
		override protected function createChildren():void {
			// Call the createChildren() method of the superclass.
    		super.createChildren();
    		this.styleName = "viewerBackground";
    		
    		// Bind events
    		_loader.contentLoaderInfo.addEventListener(Event.COMPLETE, swfComplete);
			addEventListener(Event.RESIZE, sizeChanged);
			systemManager.stage.addEventListener(KeyboardEvent.KEY_DOWN, keyboardHandler);

			// Create a visible container for the swf
			_swfContainer = new Canvas();
			_swfContainer.visible = false;
			this.addChild(_swfContainer);
			
			// Add the swf to the invisible container.
			var uic:UIComponent = new UIComponent();
			_swfContainer.addChild(uic);
			uic.addChild(_loader);
			
			_paperContainer = new ZoomCanvas();
			_paperContainer.percentHeight = 100;
			_paperContainer.percentWidth = 100;
			_paperContainer.addEventListener(FlexEvent.UPDATE_COMPLETE,updComplete);
			_paperContainer.x = 2.5;
			this.addChild(_paperContainer);
			
			createDisplayContainer();
		}
		
		private function onframeenter(event:Event):void{
			if(event.target.content != null){
				event.target.content.stop();
			}
		}
		
		private function updComplete(event:Event):void	{
			if(_scrollToPage>0){
				var vg:Number = new Number(_paperContainer.getStyle("verticalGap"));
				_paperContainer.verticalScrollPosition = _pageList[_scrollToPage-1].y;
				_paperContainer.horizontalScrollPosition = 0;
				_scrollToPage = 0;
			}

			repositionPapers();
		}
		
		private function bytesLoaded(event:Event):void{
			event.target.loader.loaded = true;
	
			var bFound:Boolean=false;
			for(var i:int=0;i<_loaderList.length;i++){
				if(!_loaderList[i].loaded){
					_loaderList[i].loadBytes(_libMC.loaderInfo.bytes);
					bFound = true;
					break;
				}
			}
			
			if(!bFound){
				dispatchEvent(new Event("onPapersLoaded"));
				_bbusyloading = false;
				repositionPapers();
			}			
		}
		
		private function repositionPapers():void{
			if(!_bbusyloading){
				var loaderidx:int=0;
				var bFoundFirst:Boolean = false;
				
					for(var i:int=0;i<_pageList.length;i++){
						if(!bFoundFirst && ((i) * (_pageList[i].height + 6)) >= _paperContainer.verticalScrollPosition){
						bFoundFirst = true;
						currPage = i + 1;
					}
						
					if(checkIsVisible(i)){
						if(_pageList[i].numChildren<2 || (_pageList[i].dupIndex == searchPageIndex && _pageList[i].numChildren<3)){
							_loaderList[loaderidx].content.gotoAndStop(_pageList[i].dupIndex);
							_pageList[i].addChild(_loaderList[loaderidx]);
						}

						if(_pageList[i].dupIndex == searchPageIndex && searchShape.parent != _pageList[i]){
							_pageList[i].addChildAt(searchShape,_pageList[i].numChildren);
						}else if(_pageList[i].dupIndex == searchPageIndex && searchShape.parent == _pageList[i]){
							_pageList[i].setChildIndex(searchShape,_pageList[i].numChildren -1);
						}
						
						loaderidx++;
					}else{
						if(_pageList[i].numChildren>0){
						_pageList[i].source = null;
						_pageList[i].removeChildAt(0);
						}					
					}
				}
			}			
		}
		
		private function checkIsVisible(pageIndex:int):Boolean{
			try{
				if(ViewMode == "Tile"){
					return  _pageList[pageIndex].parent.y + _pageList[pageIndex].height >= _paperContainer.verticalScrollPosition && 
						 	(_pageList[pageIndex].parent.y - _pageList[pageIndex].height) < (_paperContainer.verticalScrollPosition + _paperContainer.height);
				}else{
					return  ((pageIndex + 1) * (_pageList[pageIndex].height + 6)) >= _paperContainer.verticalScrollPosition && 
						 	((pageIndex) * (_pageList[pageIndex].height + 6)) < (_paperContainer.verticalScrollPosition + _paperContainer.height);
				}
			}catch(e:Error){
				return false;	
			}
			return false;
		}		
		
		private function createDisplayContainer():void{
			if(_paperContainer.numChildren>0){_paperContainer.removeAllChildren();}
			
			if(_viewMode == "Tile"){
				_displayContainer = new FlowBox();
				_displayContainer.setStyle("horizontalAlign", "left");
				_scale = 0.243;
			}else{
				_displayContainer = new mx.containers.VBox();
				_displayContainer.setStyle("horizontalAlign", "center");
			}
			
			_displayContainer.setStyle("verticalAlign", "center");
			_displayContainer.percentHeight = 100;
			_displayContainer.percentWidth = 96;
			_displayContainer.useHandCursor = true;
			
			_paperContainer.addChild(_displayContainer);
			
			_initialized=true;
		}
				
		private function keyboardHandler(event:KeyboardEvent):void{
			if(event.keyCode == Keyboard.PAGE_DOWN){
				_paperContainer.verticalScrollPosition = _paperContainer.verticalScrollPosition + 300;  
			}
			if(event.keyCode == Keyboard.PAGE_UP){
				_paperContainer.verticalScrollPosition = _paperContainer.verticalScrollPosition - 300;  
			}
			if(event.keyCode == Keyboard.HOME){
				_paperContainer.verticalScrollPosition = 0;
			}
			if(event.keyCode == Keyboard.END){
				_paperContainer.verticalScrollPosition = _paperContainer.maxVerticalScrollPosition;
			}
		}
		
		private function sizeChanged(evt:Event):void{
			repaint();
		}
		
		override protected function commitProperties():void {
			super.commitProperties();
			
			if(_swfFileChanged && _swfFile != null && _swfFile.length > 0){ // handler for when the Swf file has changed.
			
				dispatchEvent(new Event("onPapersLoading"));
				
				var fLoader:ForcibleLoader = new ForcibleLoader(_loader);
				fLoader.load(new URLRequest(_swfFile));
				 				
				_swfFileChanged = false;
			}
			
		}
		
		private function resizeMc(mc:MovieClip, maxW:Number, maxH:Number=0, constrainProportions:Boolean=true):void{
		    maxH = maxH == 0 ? maxW : maxH;
		    mc.width = maxW;
		    mc.height = maxH;
		    if (constrainProportions) {
		        mc.scaleX < mc.scaleY ? mc.scaleY = mc.scaleX : mc.scaleX = mc.scaleY;
		    }
		}		
		
		private function swfComplete(event:Event):void{
			_libMC = event.currentTarget.content as MovieClip;

			_swfLoaded = true
			repaint();
		}		
		
		private function repaint():void{
			if(!_swfLoaded){return;}
			
			_displayContainer.removeAllChildren();
			_pageList = new Array(_libMC.framesLoaded);			
			numPages = _libMC.framesLoaded;
			
			_libMC.stop();
			_libMC.gotoAndStop(1);
			
			if(_viewMode == "Tile"){
				_loaderList = new Array((Math.round(_paperContainer.height/(_libMC.height*0.23))) * ((Math.round(_paperContainer.width/(_libMC.width*0.23)))) + ((Math.round(_paperContainer.width/(_libMC.width*0.23)))*3));
				if(_loaderList.length>_libMC.framesLoaded){_loaderList = new Array(_libMC.framesLoaded);}
			}else{
				_loaderList = new Array(Math.round(_paperContainer.height/(_libMC.height*0.1))+1);
			}
			
			for(var li:int=0;li<_loaderList.length;li++){
				_loaderList[li] = new DupLoader();
	        	_loaderList[li].contentLoaderInfo.addEventListener(Event.COMPLETE, bytesLoaded);
				_loaderList[li].addEventListener(Event.ENTER_FRAME,onframeenter);
			}
			
			for(var i:int=0;i<_libMC.framesLoaded;i++){
				createPaper(_libMC,i+1);
			}
			
			addPages();
			
			// kick off the first page to load
			if(_loaderList.length>0){_bbusyloading = true; _loaderList[0].loadBytes(_libMC.loaderInfo.bytes);}			
		}
		
		private var snap:TextSnapshot;
		private var searchIndex:int = -1;		
		private var searchPageIndex:int = -1;
		private var searchShape:ShapeMarker;
		private var prevSearchText:String = "";
		
		public function searchText(text:String):void{
			var tri:Array;
			if(prevSearchText != text){
				searchIndex = -1;
				searchPageIndex = -1;
				prevSearchText = text;
			}
			if(searchShape!=null && searchShape.parent != null){searchShape.parent.removeChild(searchShape);}
	
			// start searching from the current page
			if(searchPageIndex == -1){
				searchPageIndex = currPage;
			}else{
				searchIndex = searchIndex + text.length;
			}
			
			_libMC.gotoAndStop(searchPageIndex);

			while((searchPageIndex -1) < _libMC.framesLoaded){
				snap = _libMC.textSnapshot;
				searchIndex = snap.findText((searchIndex==-1?0:searchIndex),text,false);
				
				if(searchIndex > 0){ // found a new match
					searchShape = new ShapeMarker();
					searchShape.graphics.beginFill(0x0095f7,0.3);

					for(var ti:int=0;ti<text.length;ti++){
						tri = snap.getTextRunInfo(searchIndex+ti,searchIndex+ti);
						searchShape.graphics.drawRect(tri[0].corner3x,tri[0].corner1y,tri[0].corner1x-tri[0].corner3x,tri[0].corner3y-tri[0].corner1y);
					}
					
					searchShape.graphics.endFill();
					gotoPage(searchPageIndex);
					break;
				}
				
				searchPageIndex++;
				searchIndex = -1;
				_libMC.gotoAndStop(searchPageIndex);
			}
			
			if(searchIndex == -1){ // searched the end of the doc.
				dispatchEvent(new Event("onNoMoreSearchResults"));
				prevSearchText = "";
			}
		}
		
		private function createPaper(mc:MovieClip,index:int):void {
			var di:DupImage = new DupImage(); 
			di.scaleX = di.scaleY = _scale;
			di.dupIndex = index;
		    di.width = mc.width;
		    di.height = mc.height;
		    di.addEventListener(MouseEvent.MOUSE_OVER,dupImageMoverHandler);
		    di.addEventListener(MouseEvent.MOUSE_OUT,dupImageMoutHandler);
		    di.addEventListener(MouseEvent.CLICK,dupImageClickHandler);
			_pageList[index-1] = di;
		}	
				
		private function dupImageClickHandler(event:MouseEvent):void{
			if(_viewMode == "Tile" && event.target != null){
				ViewMode = 'Portrait';
				_scrollToPage = (event.target.parent as DupImage).dupIndex;
			}
		}
		
		private function dupImageMoverHandler(event:MouseEvent):void{
			if(_viewMode == "Tile" && event.target != null){
				addGlowFilter(event.target.parent as DupImage);
			}
		}
		
		private function dupImageMoutHandler(event:MouseEvent):void{
			if(_viewMode == "Tile" && event.target != null){
				(event.target.parent as DupImage).filters = null;
			}
		}
				
		private function addPages():void{
			for(var pi:int=0;pi<_pageList.length;pi++){
				_displayContainer.addChild(_pageList[pi]);
			}
		}
		
		public function printPaper():void{
			var pj:PrintJob = new PrintJob();
			if(pj.start()){
				_libMC.stop();
				
				for(var i:int=0;i<_libMC.framesLoaded;i++){
					_libMC.gotoAndStop(i+1);
					pj.addPage(_swfContainer);
				}			
				
				pj.send();
			}
		}
		
		private function addGlowFilter(img:Image):void{
			var filter : flash.filters.GlowFilter = new flash.filters.GlowFilter(0x111111, 1, 5, 5, 2, 1, false, false);
			 img.filters = [ filter ];   
		}
				
		private function addDropShadow(img:Image):void
		{
			 var filter : DropShadowFilter = new DropShadowFilter();
			 filter.blurX = 4;
			 filter.blurY = 4;
			 filter.quality = 2;
			 filter.alpha = 0.5;
			 filter.angle = 45;
			 filter.color = 0x202020;
			 filter.distance = 6;
			 filter.inner = false;
			 img.filters = [ filter ];           
		 }		
	}
}
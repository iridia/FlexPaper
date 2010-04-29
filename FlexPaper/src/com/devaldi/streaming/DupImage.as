/* 
Copyright 2009 Erik Engström

This file is part of FlexPaper.

FlexPaper is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

FlexPaper is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with FlexPaper.  If not, see <http://www.gnu.org/licenses/>.	
*/

package com.devaldi.streaming
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.filters.DropShadowFilter;
	
	import mx.controls.Image;
	
	public class DupImage extends Image
	{
		public var dupIndex:int = 0;
		public var dupScale:Number = 0;
		public var isBlank:Boolean = false;
		public var scaleWidth:int;
		public var scaleHeight:int;
		
		private static var bmData:BitmapData;
		
		public function DupImage(){}
		
		override public function set source(value:Object):void{
			if(value!=null){super.source = value;}
			
			if(value!=null){
				if(this.filters.length==0){addDropShadow(this);}
				isBlank = false;
			}
		}
		
		public function setBlank():void{
			if(bmData==null||(bmData!=null&&bmData.width!=scaleWidth)||(bmData!=null&&bmData.height!=scaleHeight)){
				bmData = new BitmapData(scaleWidth, scaleHeight, false, 0xFFFFFF);
			}
			
			var b:Bitmap = new Bitmap(bmData);
			
			super.source = b; 
			if(this.filters.length==0){addDropShadow(this);}
			isBlank = true;			
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
			 filter.distance = 4;
			 filter.inner = false;
			 img.filters = [ filter ];           
		 }			
		
		public function removeAllChildren():void{
			while(numChildren > 0)
				delete(removeChildAt(0));
		}
	}
}
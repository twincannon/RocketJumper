package entities;
import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.FlxG;
import openfl.Assets;

/**
 * Props are assorted images used as decoration in the levels of the game
 * @author ...
 */
class Prop extends FlxSprite
{
	public function new( X:Float = 0, Y:Float = 0, W:Int = 0, H:Int = 0, XFlip:Bool, YFlip:Bool, Angle:Float, Filename:String ) 
	{
		super(X, Y);
		
		var path = "assets/images/";
		loadGraphic(Assets.getBitmapData(path + Filename), false);
		
		origin = FlxPoint.get(0, height);
		
		y -= height;
		
		scale = FlxPoint.get(W / width, H / height);
		setSize(W, H);
		
		angle = Angle;
		
		// All of the goofiness above is because Tiled uses the bottom-left corner as origin.
		// This leaves props hitboxes way off. If I ever want prop collision, I'll have to fix this (or make sure not to rotate). (centeroffsets, centerorigin, updatehitbox don't work)
		
		flipX = XFlip;
		flipY = YFlip; 
	}
	
	override public function update(elapsed:Float):Void 
	{
		super.update(elapsed);
		//angle += 0.1;
	}
}
package entities;
import flixel.FlxSprite;
import flixel.FlxObject;
import flixel.FlxG;

/**
 * ...
 * @author ...
 */
class Platform extends FlxSprite
{
	public function new( X:Float = 0, Y:Float = 0, W:Float = 20 ) 
	{
		super( X, Y );
		makeGraphic(Std.int(W), 2);

		camera = Reg.worldCam;
		moves = false;
		immovable = true;
		
		pixelPerfectRender = Reg.shouldPixelPerfectRender;

		allowCollisions = FlxObject.CEILING;
	}
	
	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
	}
}
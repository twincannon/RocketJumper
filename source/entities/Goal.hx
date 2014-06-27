package entities;
import flixel.FlxSprite;

/**
 * ...
 * @author 
 */
class Goal extends FlxSprite
{
	public var number:Int = 0;
	
	public function new( X:Float = 0, Y:Float = 0 ) 
	{
		super( X, Y );

		loadGraphic(AssetPaths.goal__png, true, 20, 40);
		camera = Reg.worldCam;
		animation.add( "idle", [ for (i in 0...4) i ], 5 );
		animation.play("idle");
		
		moves = false;
		
		pixelPerfectRender = Reg.shouldPixelPerfectRender;
	}
}
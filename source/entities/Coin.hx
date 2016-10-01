package entities;
import flixel.FlxSprite;

/**
 * ...
 * @author ...
 */
class Coin extends FlxSprite
{
	public function new( X:Float = 0, Y:Float = 0 ) 
	{
		super( X, Y );

		loadGraphic(AssetPaths.cursor__png, false, 20, 20);
		moves = false;
		
		pixelPerfectRender = Reg.shouldPixelPerfectRender;
	}
}
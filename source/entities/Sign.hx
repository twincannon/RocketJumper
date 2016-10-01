package entities;
import flixel.FlxSprite;

/**
 * ...
 * @author 
 */
class Sign extends FlxSprite
{

	public var signText:String;
	
	public function new( X:Float = 0, Y:Float = 0, Text:String = "I'm a sign!" ) 
	{
		super( X, Y );
		signText = Text;
		loadGraphic(AssetPaths.sign__png, true, 33, 29);
		moves = false;
		pixelPerfectRender = Reg.shouldPixelPerfectRender;
		x -= 6;
		y -= 9;
	}
	
}
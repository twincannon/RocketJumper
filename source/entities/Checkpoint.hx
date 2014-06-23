package entities;
import flixel.FlxObject;

/**
 * ...
 * @author 
 */
class Checkpoint extends FlxObject
{
	public var number:Int = 0;
	
	public function new(X:Float = 0, Y:Float = 0, W:Float = 0, H:Float = 0, Num:Int = 0) 
	{
		super( X, Y, W, H );
		setPosition( X, Y );
		setSize( W, H );
		number = Num;
		moves = false;
	}
}
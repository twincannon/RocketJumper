package entities;

import flixel.FlxG;
import flixel.FlxSprite;

class Explosion extends FlxSprite
{
	
	public function new(X:Float = 0, Y:Float = 0)
	{
		super(X, Y);
		
		loadGraphic("assets/images/explosion.png", true, 36, 36);
		setSize( 1, 1 );
		centerOffsets();
		animation.add("explode", [for (i in 0...16) i], 30, false);
		animation.play("explode");
	}
	
	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		
		if ( animation.finished )
			destroy();
	}
}
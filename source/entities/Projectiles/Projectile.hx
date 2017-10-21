package entities.projectiles;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxObject;

class Projectile extends FlxSprite
{
	private static inline var PROJECTILE_LIFETIME:Float = 10.0;
    private var _timeAlive:Float = 0;

	override public function new(X:Float = 0, Y:Float = 0)
	{
		super(X, Y);


		pixelPerfectRender = Reg.shouldPixelPerfectRender;

	}

	private function postInitialize():Void
	{
		setSize( 1, 1 );
		centerOffsets();
		centerOrigin();
		
		Reg.getPlayState().rockets.add(this);
	}

    override public function update(elapsed:Float):Void
    {
		super.update(elapsed);

		//@TODO change this from mapGroup to "collidable" group
		// Projectile has to be 2nd parameter here or it goes null before finish checking? Weird
		FlxG.collide( Reg.mapLoader.mapGroup, this, onCollide );

		if ( _timeAlive >= PROJECTILE_LIFETIME )
		{
			super.destroy();
			this.destroy();
		}

		_timeAlive += elapsed;
    }

	private function onCollide(collidable:FlxObject, projectile:FlxObject):Void
	{
		// Hack to get around collisions being detected early on sloped tiles
		if (this.touching <= 0)
			return;
		
		collisionFound(collidable, projectile);
	}

	private function collisionFound(collidable:FlxObject, projectile:FlxObject):Void
	{
		super.destroy();
		this.destroy();
	}
}
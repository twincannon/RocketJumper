package entities.projectiles;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxObject;
import flixel.math.FlxPoint;
import flixel.system.FlxSound;
import openfl.Assets;
import flixel.util.FlxSpriteUtil; //for debug drawing
import flixel.util.FlxColor;
import flixel.addons.display.shapes.FlxShape;
import flixel.math.FlxVector;
import entities.Explosion;

class Rocket extends Projectile
{
	private static inline var ROCKET_RADIUS:Float = 80;
	private static inline var ROCKET_ENHANCE_TIMER:Float = 0.6;
	private static inline var ROCKET_AMP_X:Int = 220;
	private static inline var ROCKET_AMP_Y:Int = 220;
	private var _sndExplode:FlxSound;
	private var _sndExplodeBig:FlxSound;

	override public function new(X:Float = 0, Y:Float = 0)
	{
		super(X, Y);
		
		loadGraphic(AssetPaths.rocket__png, true, 32, 62);
		animation.add("spin", [for (i in 0...13) i], 30);
		animation.play("spin");
		scale.set(0.25, 0.25);

		projectileSize = FlxPoint.get(1, 1);
	
		
		_sndExplode = FlxG.sound.load(AssetPaths.explosion__wav);
		_sndExplodeBig = FlxG.sound.load(AssetPaths.explosionbig__wav);
		postInitialize();
		
	}
	
	public function angleshoot(X:Float, Y:Float, Speed:Int, Target:FlxPoint):Void
	{
		solid = true;
		var rangle:Float = Math.atan2(Target.y - (y + (height / 2)), Target.x - (x + (width / 2)));  //This gives angle in radians

		var truncateDigits:Int = 10000;
		rangle = Math.round(rangle * truncateDigits) / truncateDigits;

		velocity.x = Math.cos(rangle) * Speed;
		velocity.y = Math.sin(rangle) * Speed;

		// Normalize and zero out horizontal velocity if it's very small
		// this is because cos(pi/2) is an irrational number and we need rockets able to go straight down
		var cosineTolerance = 0.02;
		if(Math.abs(velocity.x) < cosineTolerance)
		{
			velocity.x = 0;
		}
	}
	
	override public function update(elapsed:Float):Void 
	{
		if ( scale.x < 0.6 && _timeAlive >= ROCKET_ENHANCE_TIMER )
		{
			scale.x *= 1.1;
			scale.y *= 1.1;
		}

		super.update(elapsed);
	}

	override private function collisionFound(collidable:FlxObject, projectile:FlxObject):Void
	{
		explode(collidable, projectile);

		super.collisionFound(collidable, projectile);
	}
	
	private function explode(R:FlxObject, M:FlxObject):Void
	{
		var player = Reg.getPlayState().player;
		
		var doBigExplosion = false;
		if ( _timeAlive >= ROCKET_ENHANCE_TIMER )
			doBigExplosion = true;
		
		var explosionRadius = doBigExplosion ? ROCKET_RADIUS * 2 : ROCKET_RADIUS;
		var explosionAmpMod = doBigExplosion ? 2.0 : 1.0;
		
		if ( player.living && !player.levelBeat && distance( getMidpoint(), player.getMidpoint() ) < explosionRadius )
		{
			//@TODO: Make this object-ambiguous: probably have to make a baseclass for player and other things
			// 		 that can get knocked around by rockets, and make this apply velocity/damage/etc to all of them
			
			//TODO make this a flxgroup for all explodable stuff and iterate through it instead of only checking for player
			
			var rocketVec:FlxVector = new FlxVector( getMidpoint().x, getMidpoint().y );
			var playerVec:FlxVector = new FlxVector( player.getMidpoint().x, player.getMidpoint().y );
			
			var direction:FlxPoint = playerVec.subtract( rocketVec.x, rocketVec.y );
			var vecDir:FlxVector = new FlxVector( direction.x, direction.y );
			var vecLength:Float = vecDir.length;
			vecDir.normalize();
			
			var strength:Float = Reg.RemapValClamped( vecLength, 0, explosionRadius, 1.0, 0.0 );
			
			// Automatically make the player "jump" when on the ground and hit by a rocket's explosion (automatic rocket jump)
			if ( player.onGround && strength > 0.5 )
			{
				player.DoJump(false);
			}
			
			// Normalize blast strength a bit to make "perfect rocketjumps" easier and more consistent
			var threshold:Float = 0.75;
			if ( strength > threshold )
				strength = 1.0;
			else
				strength = Reg.RemapValClamped( strength, threshold, 0.0, 1.0, 0.0 );

			var amplitudeX:Float = ROCKET_AMP_X * strength * explosionAmpMod;
			var amplitudeY:Float = ROCKET_AMP_Y * strength * explosionAmpMod;
			
			// Offset our falling velocity when rocketjumping (to help with pogo'ing/skipping). Be careful not to allow infinite wall-climbing!
			var fallingOffsetVel = Math.max(player.velocity.y, 0);

			player.velocity.x += vecDir.x * amplitudeX;
			player.velocity.y += vecDir.y * amplitudeY - fallingOffsetVel;
		}
		
		//@TODO modify this camera shake amount by how far away player is
		if ( doBigExplosion )
			FlxG.camera.shake(0.015, 0.15);
		else
			FlxG.camera.shake(0.003, 0.10, false);
			
		var expSpr:Explosion = new Explosion( getMidpoint().x, getMidpoint().y );
		FlxG.state.add(expSpr);
		
		if( doBigExplosion )
			expSpr.scale = FlxPoint.get(2, 2);
		
		if ( doBigExplosion )
		{
			_sndExplodeBig.proximity(x, y, player, FlxG.width);
			_sndExplodeBig.setPosition(x, y);
			_sndExplodeBig.play();
		}
		else
		{
			_sndExplode.proximity(x, y, player, FlxG.width * 3);
			_sndExplode.setPosition(x, y);
			_sndExplode.play();
		}
	}
	
	public static inline function distance(p0:FlxPoint, p1:FlxPoint) : Float
    {
        var x = p0.x-p1.x;
        var y = p0.y-p1.y;
        return Math.sqrt(x*x + y*y);
    }	
}




package entities;

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

class Rocket extends FlxSprite
{
	private static inline var ROCKET_RADIUS:Float = 80;
	private static inline var ROCKET_ENHANCE_TIMER:Float = 0.6;
	private static inline var ROCKET_AMP_X:Int = 220;
	private static inline var ROCKET_AMP_Y:Int = 220;
	private static inline var ROCKET_LIFETIME:Float = 10.0;
	private var m_flTimeAlive:Float = 0;
	private var _sndExplode:FlxSound;
	private var _sndExplodeBig:FlxSound;

	public function new(X:Float = 0, Y:Float = 0)
	{
		super(X, Y);
		loadGraphic(AssetPaths.rocket__png, true, 32, 62);
		animation.add("spin", [for (i in 0...13) i], 30);
		animation.play("spin");
		scale.set(0.25, 0.25);
		setSize( 1, 1 );
		centerOffsets();
		centerOrigin();
		pixelPerfectRender = Reg.shouldPixelPerfectRender;
		
		Reg.getPlayState().rockets.add(this);
		
		_sndExplode = FlxG.sound.load(AssetPaths.explosion__wav);
		_sndExplodeBig = FlxG.sound.load(AssetPaths.explosionbig__wav);
	}
	
	public function angleshoot(X:Float, Y:Float, Speed:Int, Target:FlxPoint):Void
	{
		super.reset(X, Y);
		
		solid = true;
		var rangle:Float = Math.atan2(Target.y - (y + (height / 2)), Target.x - (x + (width / 2)));  //This gives angle in radians
		velocity.x = Math.cos(rangle) * Speed;
		velocity.y = Math.sin(rangle) * Speed;
	}
	
	override public function update(elapsed:Float):Void 
	{
		super.update(elapsed);
		
		if ( scale.x < 0.6 && m_flTimeAlive >= ROCKET_ENHANCE_TIMER )
		{
			scale.x *= 1.1;
			scale.y *= 1.1;
		}
			
		m_flTimeAlive += elapsed;
		
		FlxG.collide( Reg.getPlayState().mapGroup, this, explode );
		
		if ( m_flTimeAlive >= ROCKET_LIFETIME )
		{
			super.destroy();
			this.destroy();
		}
	}
	
	private function explode(R:FlxObject, M:FlxObject):Void
	{
		if (this.touching <= 0)
			return;

		var player = Reg.getPlayState().player;
		
		var doBigExplosion = false;
		if ( m_flTimeAlive >= ROCKET_ENHANCE_TIMER )
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
				player.DoJump();
			}
			
			// Normalize blast strength a bit to make "perfect rocketjumps" easier and more consistent
			if ( strength > 0.5 )
				strength = 1.0;
			else
				strength = Reg.RemapValClamped( strength, 0.5, 0.0, 1.0, 0.0 );
				
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
			
		super.destroy();
		this.destroy();
	}
	
	public static inline function distance(p0:FlxPoint, p1:FlxPoint) : Float
    {
        var x = p0.x-p1.x;
        var y = p0.y-p1.y;
        return Math.sqrt(x*x + y*y);
    }	
}




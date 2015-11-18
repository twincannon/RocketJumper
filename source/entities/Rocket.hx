package entities;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxObject;
import flixel.math.FlxPoint;
import openfl.Assets;
import flixel.util.FlxSpriteUtil; //for debug drawing
import flixel.util.FlxColor;
import flixel.addons.display.shapes.FlxShape;
import flixel.math.FlxVector;
import entities.Explosion;

class Rocket extends FlxSprite
{
	private static inline var ROCKET_RADIUS:Float = 60;
	private static inline var ROCKET_ENHANCE_TIMER:Float = 0.5;
	private static inline var ROCKET_AMP_X:Int = 200;
	private static inline var ROCKET_AMP_Y:Int = 200;
	private static inline var ROCKET_LIFETIME:Float = 10.0;
	private var m_flTimeAlive:Float = 0;

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
		camera = Reg.worldCam;
		Reg.rockets.add(this);
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
		
		FlxG.collide( Reg.mapGroup, this, explode );
		
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
		
		var doBigExplosion = false;
		if ( m_flTimeAlive >= ROCKET_ENHANCE_TIMER )
			doBigExplosion = true;

		var explosionRadius = doBigExplosion ? ROCKET_RADIUS * 2 : ROCKET_RADIUS;
		var explosionAmpMod = doBigExplosion ? 2.0 : 1.0;
		
		
		if ( Reg.player.living && !Reg.player.levelBeat && distance( getMidpoint(), Reg.player.getMidpoint() ) < explosionRadius )
		{

			FlxG.collide( Reg.player, Reg.mapGroup ); //this is ghetto, but we need to make sure the player isn't currently inside the map or the velocity change wont work... 
												//@TODO basically we need to make rockets legit objects and handle when they're updated ourselves to properly solve this. right now they update at a point when the player/map collision in playstate isnt done or something
			
			// Automatically make the player "jump" when on the ground and hit by a rocket's explosion (automatic rocket jump)
			if (Reg.player.onGround)
				Reg.player.velocity.y = -Reg.PLAYER_JUMP_VEL;
				
			//functionize all this nonsense.....
			var rocketVec:FlxVector = new FlxVector( getMidpoint().x, getMidpoint().y );
			var playerVec:FlxVector = new FlxVector( Reg.player.getMidpoint().x, Reg.player.getMidpoint().y );
			
			var direction:FlxPoint = playerVec.subtract( rocketVec.x, rocketVec.y );
			var vecDir:FlxVector = new FlxVector( direction.x, direction.y );
			var vecLength:Float = vecDir.length;
			vecDir.normalize();
			
			var distance:Float = Reg.RemapValClamped( vecLength, 0, explosionRadius, 1.0, 0.0 );
			
			//normalize distance a bit here. this is to make "perfect rocketjumps" easier and less frame-perfect //@TODO: consider removing this or something? with auto-rj's now
			if ( distance > 0.5 )
			{
				distance = 1.0;
			}
			else
				distance = Reg.RemapValClamped( distance, 0.5, 0.0, 1.0, 0.0 );
				
			var amplitudeX:Float = ROCKET_AMP_X * distance * explosionAmpMod;
			var amplitudeY:Float = ROCKET_AMP_Y * distance * explosionAmpMod;
			
			// Offset our falling velocity when rocketjumping (to help with pogo'ing/skipping), with a little extra. Be careful not to allow infinite wall-climbing!
			var bonusvel = Math.max(Reg.player.velocity.y, 0) + 15;
			
			if ( Reg.player.velocity.y < -(Reg.PLAYER_JUMP_VEL - 80) && Reg.player.velocity.y >= -(Reg.PLAYER_JUMP_VEL) )
			{
				Reg.player.velocity.y = -Reg.PLAYER_JUMP_VEL;
			}
			
			Reg.player.velocity.x += vecDir.x * amplitudeX;
			Reg.player.velocity.y += vecDir.y * amplitudeY - bonusvel;
		}
		
		//TODO make this a flxgroup for all explodable stuff and iterate through it instead of only checking for player
		
		//@TODO modify this camera shake amount by how far away player is
		if ( doBigExplosion )
			FlxG.camera.shake(0.015, 0.15);
		else
			FlxG.camera.shake(0.003, 0.10, false);
			
		var expSpr:Explosion = new Explosion( getMidpoint().x, getMidpoint().y );
		FlxG.state.add(expSpr);
		
		if( doBigExplosion )
			expSpr.scale = FlxPoint.get(2, 2);
			
			
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




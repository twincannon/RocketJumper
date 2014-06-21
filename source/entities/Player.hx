package entities;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxObject;
import flixel.group.FlxGroup;
import openfl.Assets;
import entities.Rocket;
import flixel.util.FlxAngle;
import flixel.util.FlxPoint;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.XboxButtonID;
import flixel.util.FlxVector;

class Player extends FlxSprite
{
	public var onGround:Bool; 
	private var landing:Bool = false;
	private var firing:Bool = false;
	private var running = false;
	private var m_bJumpHeldNoRelease:Bool = false; //for mario style variable jump height
	private inline static var PLAYER_FRAMERATE = 15;
	private var m_sprFireEffect:FlxSprite;
	private var m_flAimAnimTime:Float = 0;
	private var m_flOldMouseAngle:Float = 0;
	private var m_gamePad:FlxGamepad;
	private var m_bJumpHeldThisFrame:Bool = false;
	private var m_bJumpPressedThisFrame:Bool = false;
	private var m_OldGamepadAxis:FlxPoint = FlxPoint.get(0, 0);
	private var m_bAimAnimDirty:Bool = false;
	private var m_flRocketFireTimer:Float = 0;
	public var melting:Bool = false;
	public var living:Bool = true;
	public var checkPointNum:Int = 0;
	public var spawnPoint:FlxPoint;
	public var originalSpawnPoint:FlxPoint;
	public var levelTimer:Float = 0;
	public var levelBeat:Bool = false;
	public var crosshairLocation:FlxPoint = FlxPoint.get(0, 0);
	public var usingMouse = true;
	public var oldMouseScreenXY:FlxPoint = FlxPoint.get(0, 0);
	public var crosshairLine:FlxSprite;
	public var cameraFollowPoint:FlxSprite;
	public var gamepadTryNextLevel:Bool;

	public function new(X:Float = 0, Y:Float = 0)
	{
		super(X, Y);		
		
		loadGraphic(Assets.getBitmapData("assets/images/player.png"), true, 58, 58);
		
		cameraFollowPoint = new FlxSprite();
		cameraFollowPoint.setSize( 1, 1 );
		cameraFollowPoint.allowCollisions = FlxObject.NONE;
		
		animation.add("idle", [0,1], Std.int(PLAYER_FRAMERATE / 5));
		animation.add("run", [for (i in 2...12) i], PLAYER_FRAMERATE);
		animation.add("runstop", [for (i in 12...17) i], PLAYER_FRAMERATE, false );
		animation.add("jump", [for (i in 17...22) i], Std.int(PLAYER_FRAMERATE/3), false );
		animation.add("land", [for (i in 22...24) i], PLAYER_FRAMERATE, false );
		animation.add("fire", [38, 39, 40, 39, 38], PLAYER_FRAMERATE * 2, false );
		animation.add("melt", [for (i in 42...50) i], Std.int(PLAYER_FRAMERATE/3), false );
		
		animation.add("aim_0", [32]);
		animation.add("aim_18", [31]);
		animation.add("aim_36", [30]);
		animation.add("aim_54", [29]);
		animation.add("aim_72", [28]);
		animation.add("aim_90", [27]);
		animation.add("aim_108", [33]);
		animation.add("aim_126", [34]);
		animation.add("aim_144", [35]);
		animation.add("aim_162", [36]);
		animation.add("aim_180", [37]);
		
		animation.play("idle");
		facing = FlxObject.RIGHT;
		setFacingFlip( FlxObject.LEFT, false, false );
		setFacingFlip( FlxObject.RIGHT, true, false );
		setFacingFlip( FlxObject.LEFT + FlxObject.DOWN, false, true );
		setFacingFlip( FlxObject.RIGHT + FlxObject.DOWN, true, true );
		
		//tweak player's hitbox
		width = 18;
		height = 32;
		offset.set(20, 26);

		//another interesting way of handling movement, with maxvel and accel
		//https://github.com/HaxeFlixel/flixel-demos/blob/master/Editors/TiledEditor/source/PlayState.hx
		
		//player gravity/friction (drag gets re-set every frame in handleinput())
		acceleration.y = Reg.GRAVITY;
		drag.x = Reg.PLAYER_DRAG;
	}
	
	// --------------------------------------------------------------------------------------
	// Spawn fire effect (called from playstate so we can add it after player sprite)
	// --------------------------------------------------------------------------------------
	public function addFireEffect():Void
	{
		m_sprFireEffect = new FlxSprite();
		m_sprFireEffect.loadGraphic(AssetPaths.fireeffect__png, true, 29, 17);
		m_sprFireEffect.animation.add("blast", [for (i in 0...8) i], 30, false); //remember: the for loop here goes from startframe to endframe+1 (i.e. 0...8 means 0-7)
		m_sprFireEffect.setSize(1, 1);
		m_sprFireEffect.centerOffsets();
		m_sprFireEffect.kill();
		
		FlxG.state.add(m_sprFireEffect); //@TODO make stage a reg variable like in that skull multiplayer game example, so we can just reference it whenever. ALSO make player actually created from the placeentities func...
		
		crosshairLine = new FlxSprite();
		crosshairLine.loadGraphic(AssetPaths.line__png, true, 1, 75);
		crosshairLine.setSize(1, 1);
		crosshairLine.scrollFactor.set( 0, 0 );
		FlxG.state.add(crosshairLine);
	}
	
	public function goalMet():Void
	{
		if ( !levelBeat )
		{
			checkPointNum = 0;
			levelBeat = true;
			velocity.x = 0;
		}
	}
	
	// --------------------------------------------------------------------------------------
	// Update
	// --------------------------------------------------------------------------------------
	override public function update():Void
	{
		HandleDeath();
		HandleAnimation();
		HandleJumping( m_bJumpHeldThisFrame, m_bJumpPressedThisFrame );
		HandleInput(); //handle input, update velocity
		HandleGamepadInput();
		UpdateFireEffect(); //muzzleflash
		
		m_flRocketFireTimer -= FlxG.elapsed;
		
		//@TODO .. so.. uh.. there's a pretty serious bug here where fraps was causing the game
		//to run at half speed, and the timer was running at half speed too
		if ( levelTimer > 0 && !levelBeat )
			levelTimer += FlxG.elapsed;
			
		cameraFollowPoint.setPosition( getMidpoint().x, getMidpoint().y );
		
		super.update();
	}
	
	// --------------------------------------------------------------------------------------
	// Keyboard/mouse input
	// --------------------------------------------------------------------------------------
	public function HandleInput():Void
	{
		if ( FlxG.keys.justPressed.R )
			Resurrect();
			
			
		if ( oldMouseScreenXY.x != FlxG.mouse.screenX || oldMouseScreenXY.y != FlxG.mouse.screenY )
			usingMouse = true;
			
		oldMouseScreenXY = FlxPoint.get( FlxG.mouse.screenX, FlxG.mouse.screenY );
		
		if ( !living || levelBeat )
			return;
		
		var mouseAngle:Float = FlxAngle.getAngle( getMidpoint(), FlxPoint.get(FlxG.mouse.x, FlxG.mouse.y));
		
		if (FlxG.mouse.pressed && m_flRocketFireTimer <= 0.0)
			FireBullet( getMidpoint(), FlxPoint.get(FlxG.mouse.x, FlxG.mouse.y), mouseAngle );
		
		if (FlxG.keys.anyPressed(["LEFT", "A"]))
			Walk( FlxObject.LEFT );
			
		if (FlxG.keys.anyPressed(["RIGHT", "D"]))
			Walk( FlxObject.RIGHT );
		
		var jumpkeys = ["UP", "W", "SPACE"];
		m_bJumpHeldThisFrame = FlxG.keys.anyPressed(jumpkeys);
		m_bJumpPressedThisFrame = FlxG.keys.anyJustPressed(jumpkeys);
		
		// Velocity limiter (there's also maxVelocity.x I could use?)
		if ( onGround )
		{
			if ( velocity.x > Reg.PLAYER_MAX_SPEED )
				velocity.x = Reg.PLAYER_MAX_SPEED;
			else if (velocity.x < -Reg.PLAYER_MAX_SPEED)
				velocity.x = -Reg.PLAYER_MAX_SPEED;
		}
		
		// Less drag when airborn
		drag.x = onGround ? Reg.PLAYER_DRAG : Reg.PLAYER_DRAG_AIR;
	}
	
	// --------------------------------------------------------------------------------------
	// Game pad input
	// --------------------------------------------------------------------------------------
	private function HandleGamepadInput():Void
	{
		m_gamePad = FlxG.gamepads.lastActive;
		if ( m_gamePad == null )
			return;
			
		if ( m_gamePad.justPressed(XboxButtonID.X) )
			Resurrect();
			
		if ( m_gamePad.justPressed(XboxButtonID.Y) )
			gamepadTryNextLevel = true;
			
		if ( !living || levelBeat )
			return;
		
		var xboxJumpPressed = m_gamePad.justPressed(XboxButtonID.A) ||
							  m_gamePad.justPressed(XboxButtonID.DPAD_UP) ||
							  m_gamePad.justPressed(XboxButtonID.RIGHT_ANALOGUE) ||
							  m_gamePad.justPressed(XboxButtonID.RB);
		
		var xboxFirePressed = m_gamePad.getAxis(XboxButtonID.RIGHT_TRIGGER) > 0.25 ||
							  m_gamePad.justPressed(XboxButtonID.RIGHT_ANALOGUE) ||
							  m_gamePad.justPressed(XboxButtonID.RB);
							  
							  
		
		m_bJumpHeldThisFrame = ( m_bJumpHeldThisFrame || xboxJumpPressed );
		m_bJumpPressedThisFrame = ( m_bJumpPressedThisFrame || xboxJumpPressed );
		
		if ( m_gamePad.pressed(XboxButtonID.DPAD_LEFT) )
			Walk( FlxObject.LEFT );
		
		if ( m_gamePad.pressed(XboxButtonID.DPAD_RIGHT) )
			Walk( FlxObject.RIGHT );
		
		m_gamePad.deadZone = 0.0;
		var xaxis = m_gamePad.getXAxis( XboxButtonID.RIGHT_ANALOGUE_X );
		var yaxis = m_gamePad.getYAxis( XboxButtonID.RIGHT_ANALOGUE_Y );

		var vecAxis = new FlxVector( xaxis, yaxis );
		var length = vecAxis.length;
	
		//deadzone
		if ( length < 0.3 )
		{
			xaxis = m_OldGamepadAxis.x;
			yaxis = m_OldGamepadAxis.y;
		}
		
		var angle:Float = Math.atan2( yaxis, xaxis );
		crosshairLocation.x = 75 * Math.cos(angle);
		crosshairLocation.y = 75 * Math.sin(angle);
		
		if ( xaxis != m_OldGamepadAxis.x || yaxis != m_OldGamepadAxis.y )
		{
			usingMouse = false;
			m_bAimAnimDirty = true;
		}
			
		m_OldGamepadAxis = FlxPoint.get( xaxis, yaxis );
		
		if ( m_flRocketFireTimer <= 0.0 && xaxis != 0 && yaxis != 0 && xboxFirePressed )
		{
			xaxis *= 1000;
			yaxis *= 1000;
			xaxis += x + width * 0.5;
			yaxis += y + height * 0.5;
			var joyangle:Float = FlxAngle.getAngle( getMidpoint(), FlxPoint.get(xaxis, yaxis) );
			FireBullet( getMidpoint(), FlxPoint.get(xaxis, yaxis), joyangle );
		}
	}
	
	// --------------------------------------------------------------------------------------
	// Jump input
	// --------------------------------------------------------------------------------------
	private function HandleJumping( jumpHeld:Bool, jumpJustPressed:Bool ):Void
	{
		if ( !living )
			return;

		// Mario style jumping, probably removing this for good since it's just adding too much of a variable for puzzle style jumps
		/*if ( jumpHeld && m_bJumpHeldNoRelease && (last.y > y) )
		{
			velocity.y -= Reg.PLAYER_JUMPHOLD_VEL + (Math.min( Math.abs(velocity.x), Reg.PLAYER_MAX_SPEED ) * Reg.PLAYER_JUMPHOLD_VEL_MOD);
		}
		else
			m_bJumpHeldNoRelease = false;*/
		
		//if ( isTouching(FlxObject.FLOOR) )
		
		if ( velocity.y == 0 && !isTouching(FlxObject.CEILING) )//!(last.y > y) ) //account for head ceiling bonks
		{
			onGround = true;
			
			if ( jumpJustPressed )
			{
				animation.play("jump", true, 0);
				firing = false; //we can interrupt a fire animation with jumping. really need to refactor into like "TryAnimation(anim,priority,loops)" (loops = false would set force to true and frame to 0)
				velocity.y = -Reg.PLAYER_JUMP_VEL;
				onGround = false;
				m_bJumpHeldNoRelease = true;
			}
		}
		else
		{
			onGround = false;
		}
	}
	
	// --------------------------------------------------------------------------------------
	// Check whether we should be alive or dead
	// --------------------------------------------------------------------------------------
	private function HandleDeath():Void
	{
		if ( !living )
			return;
			
		if (melting) //change this into some kind of setalive system .. also rename living to like isdead or something.. dumb
		{
			var falling = true;
			if ( velocity.y < 0 )
				falling = false;
			y += falling ? 24 : 6;
			facing += falling ? 0 : FlxObject.DOWN;
			allowCollisions = FlxObject.NONE;
			acceleration.set( 0, 0 );
			drag.y = 20;
			velocity.set( 0, falling ? 18 : -18 );
			animation.play("melt", false, 0);
			living = false;
			return;
		}
	}
	
	private function Resurrect():Void
	{
		Reg.destroyRockets();
		
		FlxG.camera.follow(this);
		melting = false;
		living = true;
		
		//@TODO!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! remove all rockets on res
		//ROCKETS DONT GET REMOVED.... and i have no way of tracking them..! fuck!
		
		velocity.set(0, 0);
		allowCollisions = FlxObject.ANY;
		facing = FlxObject.RIGHT;
		acceleration.y = Reg.GRAVITY;
		drag.x = Reg.PLAYER_DRAG;
		animation.play("idle");
		x = spawnPoint.x;
		y = spawnPoint.y;
		
		if ( checkPointNum == 0 || levelBeat )
		{
			checkPointNum = 0;
			levelBeat = false;
			x = originalSpawnPoint.x;
			y = originalSpawnPoint.y;
			levelTimer = 0;
		}
	}
	// --------------------------------------------------------------------------------------
	// Animation choosing logic based on current movement states
	// --------------------------------------------------------------------------------------
	private function HandleAnimation():Void
	{
		if ( !living )
			return;
		
		/*
		 * TODO: 
			 * make an animation priority system.. if there isnt one
			 * then i can just be like "if animation doesnt loop, isnt finished, and is higher priority, dont change
			 * like playAnimation( "anim", looping, priority );
			 * 
			 * What could also work is an animation.callback system as shown here, seems to be made for it: http://pastebin.com/auh87105
			 * */
				
		if ( velocity.y == 0 && !onGround && !isTouching(FlxObject.CEILING) )
		{
			animation.play("land", true, 0);
			landing = true;
		}
		
		if ( animation.name == "land" && animation.finished ) //does finished infer looping is false?????? could use that in lieu of priority
		{
			landing = false;
			firing = false; //we can land from a firing animation
		}
		
		if ( animation.name == "fire" && animation.finished )
		{
			firing = false;
			landing = false; //firing can interrupt landing
			
			if ( velocity.y != 0 )
			{
				animation.play("jump", true, 0);
				onGround = false;
			}
		}
		
		var anim = "idle";
		
		if ( onGround )
		{
			if ( running && velocity.x != 0 )
				anim = "run";
			else
				anim = "idle";
		}
		
		if ( !landing && !firing )
		{
			if ( onGround )
			{
				if ( !running && velocity.x != 0 && animation.name != "runstop" && animation.name != "idle")
				{
					animation.play( "runstop", true, 0 );
				}
				else if ( anim == "run" || animation.name != "runstop" || (animation.name == "runstop" && animation.finished) )
				{
					animation.play( anim );
				}
			}
			else if ( animation.name != "jump" ) //if we walk off of a ledge, play jump anim
			{
				animation.play("jump", true, 0);
			}
		}
		
		var aimAngle:Float;
		if ( usingMouse )
			aimAngle = FlxAngle.getAngle( getScreenXY(), FlxPoint.get(FlxG.mouse.screenX, FlxG.mouse.screenY));
		else
			aimAngle = FlxAngle.getAngle( getScreenXY(), FlxPoint.get(getScreenXY().x + crosshairLocation.x, getScreenXY().y + crosshairLocation.y));
			
		if ( m_flOldMouseAngle != aimAngle )
		{
			m_bAimAnimDirty = true;
		}
		
		//super contrived if statement, but basically once we start "aiming", dont stop until we move again
		if ( (m_bAimAnimDirty || m_flAimAnimTime > 9999)
			&& velocity.x == 0 && velocity.y == 0
			&& !firing && !landing
			&& m_flAimAnimTime > 0.5 )
		{
			m_flAimAnimTime = 10000;
			m_bAimAnimDirty = false;
			var ang = Math.abs(aimAngle);
			var offset = 12;
			if ( ang <= 9 )
				animation.play("aim_0");
			else if ( ang <= 18 )
				animation.play("aim_18");
			else if ( ang <= 27 )
				animation.play("aim_36");
			else if ( ang <= 45  )
				animation.play("aim_54");
			else if ( ang <= 63  )
				animation.play("aim_72");
			else if ( ang <= 81  )
				animation.play("aim_90");
			else if ( ang <= 99  )
				animation.play("aim_108");
			else if ( ang <= 126  )
				animation.play("aim_126");
			else if ( ang <= 144 )
				animation.play("aim_144");
			else if ( ang <= 162 )
				animation.play("aim_162");
			else if ( ang <= 180  )
				animation.play("aim_180");
				
			if ( aimAngle < 0 )
				facing = FlxObject.LEFT;
			else
				facing = FlxObject.RIGHT;
		}
		
		m_flOldMouseAngle = aimAngle;
		
		if ( velocity.x == 0 && velocity.y == 0 )
			m_flAimAnimTime += FlxG.elapsed;
		else
			m_flAimAnimTime = 0;
		
		//set running to false for next frame now that we're done with it
		running = false;
	}
	
	// --------------------------------------------------------------------------------------
	// Run in given direction
	// --------------------------------------------------------------------------------------
	private function Walk( dir:Int ):Void
	{
		if( !firing && living )
			facing = dir;
				
		running = true;
		
		if ( dir == FlxObject.LEFT && velocity.x > -Reg.PLAYER_MAX_SPEED )
			velocity.x -= Reg.PLAYER_ACCEL;
			
		if ( dir == FlxObject.RIGHT && velocity.x < Reg.PLAYER_MAX_SPEED )
			velocity.x += Reg.PLAYER_ACCEL;
			
		if ( levelTimer == 0 )
			levelTimer += FlxG.elapsed;
			
		if ( !Reg.gameTimerStarted )
			Reg.gameTimerStarted = true;
	}
	
	// --------------------------------------------------------------------------------------
	// Handle logic for the "muzzle flash" effect
	// --------------------------------------------------------------------------------------
	private function UpdateFireEffect():Void
	{
		if ( m_sprFireEffect.alive )
		{
			if ( m_sprFireEffect.animation.finished )
			{
				m_sprFireEffect.kill();
			}
			else
			{
				m_sprFireEffect.facing = facing;
				if ( m_sprFireEffect.facing == FlxObject.LEFT )
				{
					m_sprFireEffect.flipX = true;
					m_sprFireEffect.setPosition( getMidpoint().x - 30, getMidpoint().y - 10 );
				}
				else
				{
					m_sprFireEffect.flipX = false;
					m_sprFireEffect.setPosition( getMidpoint().x + 30, getMidpoint().y - 10 );
				}
			}
		}
	}
	
	// --------------------------------------------------------------------------------------
	// Fires a rocket from our origin at given angle
	// --------------------------------------------------------------------------------------
	public function FireBullet( origin:FlxPoint, target:FlxPoint, newAngle:Float ):Void
	{
		animation.play("fire", true, 0);
		firing = true;
		
		if ( target.x < getMidpoint().x )
			facing = FlxObject.LEFT;
		else
			facing = FlxObject.RIGHT;
		
		//update muzzleflash
		m_sprFireEffect.revive();
		m_sprFireEffect.animation.play("blast", true, 0);
		
		var rocket = new Rocket( origin.x, origin.y );
		rocket.angle = newAngle;
		rocket.angleshoot( origin.x, origin.y - Reg.PLAYER_SHOOT_Y_OFFSET, Reg.ROCKET_SPEED, target );
		FlxG.state.add(rocket); 
		
		m_flRocketFireTimer = Reg.ROCKET_COOLDOWN;
		
		if ( levelTimer == 0 )
			levelTimer += FlxG.elapsed;
	}
	
	public function touchCheckpoint(P:FlxObject, C:Checkpoint):Void
	{
		if ( !levelBeat && C.number > checkPointNum )
		{
			checkPointNum = C.number;
			spawnPoint.set( C.getMidpoint().x - width/2, C.y + C.height - height );
		}
	}
}
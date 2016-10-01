package entities;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxObject;
import flixel.system.FlxSound;
import flixel.group.FlxGroup;
import openfl.Assets;
import entities.Rocket;
import flixel.math.FlxPoint;
import flixel.math.FlxAngle;
import flixel.input.gamepad.FlxGamepad;
import flixel.math.FlxVector;
import flixel.FlxCamera.FlxCameraFollowStyle;

/**
 *  The player entity. Also handles movement input and the firing of rockets.
 */
class Player extends FlxSprite
{
	public var onGround:Bool; 
	private var landing:Bool = false;
	private var firing:Bool = false;
	private var running = false;
	private inline static var PLAYER_FRAMERATE = 15;
	private var m_sprFireEffect:FlxSprite;
	private var m_flAimAnimTime:Float = 0;
	private var m_flOldMouseAngle:Float = 0;
	private var m_gamePad:FlxGamepad;
	private var m_bJumpHeldThisFrame:Bool = false;
	public var m_bJumpPressedThisFrame:Bool = false;
	private var m_bJumpReleasedSinceLastOnGround = false; // For quake style bunnyhop
	private var m_OldGamepadAxis:FlxPoint = FlxPoint.get(0, 0);
	private var m_bAimAnimDirty:Bool = false;
	private var m_flRocketFireTimer:Float = 0;
	private var m_bAimLockHeld:Bool = false;
	private var m_AimLockDir:FlxPoint = FlxPoint.get(0, 0);
	public var melting:Bool = false;
	public var living:Bool = true;
	public var checkPointNum:Int = 0;
	public var spawnPoint:FlxPoint;
	public var originalSpawnPoint:FlxPoint;
	public var levelBeat:Bool = false;
	public var crosshairLocation:FlxPoint = FlxPoint.get(0, 0);
	public var usingMouse = true;
	public var oldMouseScreenXY:FlxPoint = FlxPoint.get(0, 0);
	public var crosshairLine:FlxSprite;
	public var innerHitbox:FlxObject;
	private static inline var INNER_HITBOX_OFFSET:Int = 2;
	public var onPlatform:Bool = false;
	private var highestJumpY:Float = 0;
	private var jumpLeniencyTimer:Float = 0; //depracated with quake style
	private var _sndJump:FlxSound;
	private var _sndShoot:FlxSound;
	
	private var m_bUsingAnalogAiming:Bool = false;

	public static inline var PLAYER_WIDTH = 17;
	public static inline var PLAYER_HEIGHT = 30;
	

	public function new(X:Float = 0, Y:Float = 0)
	{
		super(X, Y);		
		
		loadGraphic(Assets.getBitmapData(AssetPaths.player__png), true, 25, 30);
		
	/*	animation.add("idle", [0,1], Std.int(PLAYER_FRAMERATE / 5));
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
		animation.add("aim_180", [37]);*/
		
		//animation.play("idle");
		facing = FlxObject.LEFT;
		setFacingFlip( FlxObject.LEFT, true, false );
		setFacingFlip( FlxObject.RIGHT, false, false );
		setFacingFlip( FlxObject.LEFT + FlxObject.DOWN, true, true );
		setFacingFlip( FlxObject.RIGHT + FlxObject.DOWN, false, true );
		
		_sndJump = FlxG.sound.load(AssetPaths.jump__wav);
		_sndShoot = FlxG.sound.load(AssetPaths.shoot__wav);
		
		// Resize the player hitbox
		width = PLAYER_WIDTH;
		height = PLAYER_HEIGHT;
		offset.set(4, 0);
		
		// Add a more lenient hitbox for harmful collisions
		innerHitbox = new FlxObject( INNER_HITBOX_OFFSET, INNER_HITBOX_OFFSET, width - INNER_HITBOX_OFFSET * 2, height - INNER_HITBOX_OFFSET * 2 );
		
		pixelPerfectRender = Reg.shouldPixelPerfectRender;
		
		// Player gravity/friction (drag gets re-set every frame in HandleInput())
		acceleration.y = Reg.GRAVITY;
		drag.x = Reg.PLAYER_DRAG;

		originalSpawnPoint = FlxPoint.get( x, y );
		spawnPoint = FlxPoint.get( x, y );
	}
	
	/** --------------------------------------------------------------------------------------------------------
	 *  Add player to state, then create and add to state the muzzleflash "fire effect" and the crosshair line.
	 */
	public function addToState():Void
	{
		FlxG.state.add(this);
		
	/*	m_sprFireEffect = new FlxSprite();
		m_sprFireEffect.loadGraphic(AssetPaths.fireeffect__png, true, 29, 17);
		m_sprFireEffect.animation.add("blast", [for (i in 0...8) i], 30, false); //remember: the for loop here goes from startframe to endframe+1 (i.e. 0...8 means 0-7)
		m_sprFireEffect.setSize(1, 1);
		m_sprFireEffect.centerOffsets();
		m_sprFireEffect.kill();
		FlxG.state.add(m_sprFireEffect);*/ //@TODO make stage a reg variable like in that skull multiplayer game example, so we can just reference it whenever. ALSO make player actually created from the placeentities func...
	}
	
	public function addCrosshairLine():Void
	{
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
			Reg.levelTimerStarted = false;
			checkPointNum = 0;
			levelBeat = true;
			velocity.x = 0;
			acceleration.x = 0;
			m_bJumpHeldThisFrame = false;
			m_bJumpPressedThisFrame = false;
			m_bJumpReleasedSinceLastOnGround = false;
		}
	}
	
	// --------------------------------------------------------------------------------------
	// Update
	// --------------------------------------------------------------------------------------
	override public function update(elapsed:Float):Void
	{
		var wasOnGround:Bool = onGround;
		
		HandleDeath();
		//HandleAnimation();
		
		HandleInput(); //handle input, update velocity
		HandleGamepadInput();
		HandleJumping( m_bJumpHeldThisFrame, m_bJumpPressedThisFrame );
		UpdateFireEffect(); //muzzleflash
		
		m_flRocketFireTimer -= elapsed;
		
		super.update(elapsed);
		
		innerHitbox.setPosition( x + INNER_HITBOX_OFFSET, y + INNER_HITBOX_OFFSET );		
		
		if (!onGround)
			highestJumpY = Math.min(y, highestJumpY);
			
		if (onGround && !wasOnGround)
		{
			//trace("jump height: " + Std.string(y - highestJumpY)); //@TODO: finish this //actually, this is "longest fall", I'd need to record takeoff point as well to get actual height TODO
			highestJumpY = y;
		}
	}
	
	// --------------------------------------------------------------------------------------
	// Keyboard/mouse input
	// --------------------------------------------------------------------------------------
	public function HandleInput():Void
	{
		if ( FlxG.keys.justPressed.R )
			Resurrect();
			
		acceleration.x = 0;
			
		// Gain control of mouse if it's not currently active
		if ( !usingMouse && (oldMouseScreenXY.x != FlxG.mouse.screenX || oldMouseScreenXY.y != FlxG.mouse.screenY) )
		{
			FlxG.mouse.reset;
			usingMouse = true;
			oldMouseScreenXY.set( FlxG.mouse.screenX, FlxG.mouse.screenY );
		}	
		
		m_bJumpHeldThisFrame = FlxG.keys.anyPressed([W, UP, SPACE]);
		m_bJumpPressedThisFrame = FlxG.keys.anyJustPressed([W, UP, SPACE]);
		
		jumpLeniencyTimer -= FlxG.elapsed;
		
		if ( m_bJumpPressedThisFrame )
			jumpLeniencyTimer = Reg.JUMP_LENIENCE_TIMER;
		
		if ( !living || levelBeat )
			return;	
		
		if (FlxG.keys.anyPressed([LEFT, A]))
			Walk( FlxObject.LEFT );
			
		if (FlxG.keys.anyPressed([RIGHT, D]))
			Walk( FlxObject.RIGHT );
		
		// If we're on a platform and hold down+jump, drop through it //@TODO: make this work elsewhere, probably in HandleJumping (so I don't have to copy it into gamepad code)
		if (FlxG.keys.anyPressed([DOWN, S]) && FlxG.keys.justPressed.SPACE && onPlatform) //@TODO: probably make W not jump anymore, since space now has unique functionality.. also add this to gamepad input
		{
			y += 6;
			m_bJumpHeldThisFrame = false;
			m_bJumpPressedThisFrame = false;
			onPlatform = false;
		}
		
		if (FlxG.mouse.pressed && m_flRocketFireTimer <= 0.0)
		{
			var mouseAngle:Float = getMidpoint().angleBetween( FlxPoint.get(FlxG.mouse.x, FlxG.mouse.y));
			
			FireBullet( getMidpoint(), FlxPoint.get(FlxG.mouse.x, FlxG.mouse.y), mouseAngle );
		}
		
		// Velocity limiter
		if ( onGround )
		{
			if ( velocity.x > Reg.PLAYER_MAX_SPEED )
				velocity.x = Reg.PLAYER_MAX_SPEED;
			else if (velocity.x < -Reg.PLAYER_MAX_SPEED)
				velocity.x = -Reg.PLAYER_MAX_SPEED;
		}
		else
		{
			onPlatform = false;
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
			
		if ( m_gamePad.justPressed.X )
			Resurrect();
		
		var xboxJumpPressed = m_gamePad.justPressed.A;
		
		var xboxFirePressed = m_gamePad.analog.value.RIGHT_TRIGGER > 0.25 ||
							  m_gamePad.justPressed.RIGHT_STICK_CLICK;
		
		if ( m_gamePad.pressed.RIGHT_SHOULDER || m_gamePad.pressed.LEFT_SHOULDER )
			m_bAimLockHeld = true;
		else
			m_bAimLockHeld = false;
		
		m_bJumpHeldThisFrame = ( m_bJumpHeldThisFrame || xboxJumpPressed );
		m_bJumpPressedThisFrame = ( m_bJumpPressedThisFrame || xboxJumpPressed );
		
		if ( !living || levelBeat )
			return;
		
		m_gamePad.deadZoneMode = FlxGamepadDeadZoneMode.CIRCULAR;
		m_gamePad.deadZone = 0.4;
				
		if ( (m_gamePad.pressed.DPAD_LEFT || m_gamePad.pressed.DPAD_RIGHT || 
			  m_gamePad.pressed.DPAD_UP   || m_gamePad.pressed.DPAD_DOWN  ||
			  m_gamePad.analog.value.LEFT_STICK_X != 0 || m_gamePad.analog.value.LEFT_STICK_Y != 0 ) && !m_bAimLockHeld)
		{
			m_AimLockDir = FlxPoint.get(0, 0);
			usingMouse = false;
		}
	
		if ( m_gamePad.pressed.DPAD_LEFT || m_gamePad.analog.value.LEFT_STICK_X < 0)
		{
			Walk( FlxObject.LEFT );
			m_AimLockDir.x = m_bAimLockHeld ? m_AimLockDir.x : -1;
		}
		else if ( m_gamePad.pressed.DPAD_RIGHT || m_gamePad.analog.value.LEFT_STICK_X > 0)
		{
			Walk( FlxObject.RIGHT );
			m_AimLockDir.x = m_bAimLockHeld ? m_AimLockDir.x : 1;
		}
		
		if ( m_gamePad.pressed.DPAD_UP || m_gamePad.analog.value.LEFT_STICK_Y < 0 )
		{
			m_AimLockDir.y = m_bAimLockHeld ? m_AimLockDir.y : -1;
		}
		else if ( m_gamePad.pressed.DPAD_DOWN || m_gamePad.analog.value.LEFT_STICK_Y > 0 )
		{
			m_AimLockDir.y = m_bAimLockHeld ? m_AimLockDir.y : 1;
		}
		
		var X = m_AimLockDir.x;
		var Y = m_AimLockDir.y;
		var aimX = X;
		var aimY = Y;
		
		
		if ( m_gamePad.justPressed.Y )
		{
			m_bUsingAnalogAiming = !m_bUsingAnalogAiming;
			Reg.getPlayState().gameHUD.setInputModeText( m_bUsingAnalogAiming ? "Analog stick style" : "D-Pad style (hold bumpers to lock aim)");
		}
			
		if ( m_bUsingAnalogAiming )
		{
			X = m_gamePad.analog.value.RIGHT_STICK_X;
			Y = m_gamePad.analog.value.RIGHT_STICK_Y;
			
			aimX = X != 0 ? X : m_OldGamepadAxis.x;
			aimY = Y != 0 ? Y : m_OldGamepadAxis.y;
		}
		
		// Store axis so we can still fire when the player has let go of the analog stick
		m_OldGamepadAxis = FlxPoint.get( aimX, aimY );
		
		if ( (X != 0 || Y != 0) && m_bUsingAnalogAiming)
		{
			usingMouse = false;
			m_bAimAnimDirty = true;
		}
		
		if ( !usingMouse )
		{
			var angle:Float = Math.atan2( aimY, aimX );
			crosshairLocation.x = 75 * Math.cos(angle);
			crosshairLocation.y = 75 * Math.sin(angle);
		}
		
		if ( m_flRocketFireTimer <= 0.0 && (aimX != 0 || aimY != 0) && xboxFirePressed )
		{
			// This is kind of hacky, but it works
			aimX *= 10000;
			aimY *= 10000;
			aimX += getMidpoint().x;
			aimY += getMidpoint().y;
			
			var joyangle:Float = getMidpoint().angleBetween( FlxPoint.get(aimX, aimY) );
			FireBullet( getMidpoint(), FlxPoint.get(aimX, aimY), joyangle );
		}
	}
	
	// --------------------------------------------------------------------------------------
	// Jump input
	// --------------------------------------------------------------------------------------
	private function HandleJumping( jumpHeld:Bool, jumpJustPressed:Bool ):Void
	{
		if ( !living )
			return;
			
		if ( !jumpHeld )
		{
			m_bJumpReleasedSinceLastOnGround = true;
		}
		
		if ( velocity.y == 0 && !isTouching(FlxObject.CEILING) ) //account for head ceiling bonks
		{
			onGround = true;
			
			if ( jumpJustPressed || (jumpHeld && m_bJumpReleasedSinceLastOnGround) )
			{
				DoJump();
			}
		}
		else
		{
			onGround = false;
		}
	}
	
	public function DoJump():Void
	{
		if ( levelBeat )
			return;
			
		//animation.play("jump", true);
		_sndJump.play();
		firing = false; //we can interrupt a fire animation with jumping. @TODO really need to refactor into like "TryAnimation(anim,priority,loops)" (loops = false would set force to true and frame to 0)
		velocity.y = -Reg.PLAYER_JUMP_VEL;
		onGround = false;
		jumpLeniencyTimer = 0;
		Reg.levelTimerStarted = true;
		m_bJumpReleasedSinceLastOnGround = false;
	}
	
	// --------------------------------------------------------------------------------------
	// Check whether we should be alive or dead
	// --------------------------------------------------------------------------------------
	private function HandleDeath():Void
	{
		if ( !living )
			return;
			
		if ( melting )
		{
			var falling = true;
			if ( velocity.y < 0 )
				falling = false;
			y += falling ? 24 : 6;
			facing += falling ? 0 : FlxObject.DOWN;
			allowCollisions = FlxObject.NONE;
			innerHitbox.allowCollisions = FlxObject.NONE;
			acceleration.set( 0, 0 );
			drag.y = 20;
			velocity.set( 0, falling ? 18 : -18 );
			//animation.play("melt");
			living = false;
			firing = false;
			return;
		}
	}
	
	public function Resurrect():Void
	{
		Reg.destroyRockets(false);
		
		var state:PlayState = cast FlxG.state;
		state.worldCam.follow(this);
		state.worldCam.zoom = 1.3333332;

		melting = false;
		living = true;
		landing = false;
		
		velocity.set(0, 0);
		allowCollisions = FlxObject.ANY;
		innerHitbox.allowCollisions = FlxObject.ANY;
		facing = FlxObject.RIGHT; //@TODO make an arg for this based on playerstart/checkpoint orientation
		acceleration.y = Reg.GRAVITY;
		drag.x = Reg.PLAYER_DRAG;
	//	animation.play("idle");
		x = spawnPoint.x;
		y = spawnPoint.y;
		
		highestJumpY = y;
		
		if ( checkPointNum == 0 || levelBeat )
		{
			checkPointNum = 0;
			levelBeat = false;
			x = originalSpawnPoint.x;
			y = originalSpawnPoint.y;
			
			Reg.resetTimers();
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
			 * make an animation priority system.. if there isnt one (real animators call this a state machine :^))
			 * then i can just be like "if animation doesnt loop, isnt finished, and is higher priority, dont change
			 * like playAnimation( "anim", looping, priority );
			 * 
			 * What could also work is an animation.callback system as shown here, seems to be made for it: http://pastebin.com/auh87105
			 * */
				
		if ( velocity.y == 0 && !onGround && !isTouching(FlxObject.CEILING) )
		{
			animation.play("land", true);
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
				animation.play("jump", true);
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
					animation.play( "runstop", true);
				}
				else if ( anim == "run" || animation.name != "runstop" || (animation.name == "runstop" && animation.finished) )
				{
					animation.play( anim );
				}
			}
			else if ( animation.name != "jump" ) //if we walk off of a ledge, play jump anim
			{
				animation.play("jump", true);
			}
		}
		
		var aimAngle:Float;
		if ( usingMouse )
			aimAngle = getScreenPosition().angleBetween( FlxPoint.get(FlxG.mouse.screenX, FlxG.mouse.screenY) );
		else
			aimAngle = getScreenPosition().angleBetween( FlxPoint.get(getScreenPosition().x + crosshairLocation.x, getScreenPosition().y + crosshairLocation.y));
			
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
		
		if ( dir == FlxObject.LEFT )
		{
			if ( !onGround && velocity.x > 0 )
				acceleration.x = -1500; // To make turning around in the air easier
			else if ( velocity.x > -Reg.PLAYER_MAX_SPEED )
				acceleration.x = -1000; // Walking on ground
			else if (!onGround) // Air accel
				acceleration.x = -100;
		}
		
		if ( dir == FlxObject.RIGHT )
		{
			if ( !onGround && velocity.x < 0 )
				acceleration.x = 1500;
			else if ( velocity.x < Reg.PLAYER_MAX_SPEED )
				acceleration.x = 1000;
			else if (!onGround)
				acceleration.x = 100;
		}
			
		Reg.levelTimerStarted = true;
			
		if ( !Reg.gameTimerStarted )
			Reg.gameTimerStarted = true;
	}
	
	// --------------------------------------------------------------------------------------
	// Handle logic for the "muzzle flash" effect
	// --------------------------------------------------------------------------------------
	private function UpdateFireEffect():Void
	{
		if ( m_sprFireEffect != null && m_sprFireEffect.alive )
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
		//animation.play("fire", true);
		firing = true;
		
		_sndShoot.play();
		
		if ( target.x < getMidpoint().x )
			facing = FlxObject.LEFT;
		else
			facing = FlxObject.RIGHT;
		
		//update muzzleflash
	//	m_sprFireEffect.revive();
	//	m_sprFireEffect.animation.play("blast", true);
		
		var rocket = new Rocket( origin.x, origin.y );
		rocket.angle = newAngle;
		rocket.angleshoot( origin.x, origin.y - Reg.PLAYER_SHOOT_Y_OFFSET, Reg.ROCKET_SPEED, target );
		
		m_flRocketFireTimer = Reg.ROCKET_COOLDOWN;
		
		Reg.levelTimerStarted = true;
	}
	
	public function touchCheckpoint(P:FlxObject, C:Checkpoint):Void
	{
		if ( !levelBeat && C.number > checkPointNum )
		{
			checkPointNum = C.number;
			spawnPoint.set( C.getMidpoint().x - width/2, C.y + C.height - height );
		}
	}
	
	public function ConstrainToMap( mapX:Float, mapY:Float, mapWidth:Int, mapHeight:Int ):Void
	{
		// Constrain to map horizontally
		if ( x < mapX )
		{
			x = mapX;
			velocity.x = 0;
		}
		else if ( x + width > mapWidth )
		{
			x = mapWidth - width;
			velocity.x = 0;
		}
		
		// Wrap around map vertically if falling off the bottom
		if ( y > mapHeight || y < mapY )
		{
			y = mapY;
			velocity.y = 0;
		}
	}
}
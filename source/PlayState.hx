package;

import openfl.Assets;

import entities.Player;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.math.FlxPoint;
import flixel.effects.postprocess.PostProcess;

import flixel.system.scaleModes.FillScaleMode;
import flixel.system.scaleModes.FixedScaleMode;
import flixel.system.scaleModes.RatioScaleMode;
import flixel.system.scaleModes.RelativeScaleMode;

using StringTools;

/**
 * A FlxState which can be used for the actual gameplay.
 */
class PlayState extends FlxState
{
	private static inline var CAM_ZOOM_MIN:Float = 1.0;
	private static inline var CAM_ZOOM_MAX:Float = 4.0;
	
	public var player:Player;

	
	public var rockets:FlxGroup = new FlxGroup(); // should really be elsewhere
	public var worldCam:FlxCamera;

	private var _crosshair:FlxSprite;

	/** -----------------------------------------------------------------
	 *  State creation and initialization
	 *  ----------------------------------------------------------------- */
	override public function create():Void
	{
		super.create();
		
		FlxG.cameras.reset();

		worldCam = new FlxCamera( 0, 0, FlxG.width, FlxG.height, 1 );
		
		FlxG.cameras.add( worldCam );
		FlxG.camera = worldCam;
	//	FlxG.camera.bgColor = 0xFF58533E;
		
		// Set the default camera to use for all newly added FlxObjects
		var defaultCams:Array<FlxCamera> = new Array<FlxCamera>();
		defaultCams.push(worldCam);
		FlxCamera.defaultCameras = defaultCams;

		Reg.mapLoader = new MapLoader();
		Reg.mapLoader.setupLevel();
		
		FlxG.camera.setScrollBoundsRect(0, 0,  Reg.mapLoader.getMapSize().x,  Reg.mapLoader.getMapSize().y);
		
		Reg.HUD = new HUD( FlxG.width, FlxG.height ); // Note: Creates and adds a second camera to FlxG.cameras
		
		addGameAssetsToState();
		
		FlxG.camera.zoom = ( (FlxG.width / FlxG.stage.stageWidth) * 2 ); // Set pixel perfect 2.0 ratio zoom (also done in onResize);
		
		worldCam.flash( FlxColor.BLACK, 0.75 );	
		
#if (cpp || neko)
		var shader = new PostProcess("assets/shaders/scanline.frag");
		FlxG.addPostProcess(shader);
#end
		worldCam.follow(player, FlxCameraFollowStyle.LOCKON, 1);
		worldCam.targetOffset.set(0, -20);
		
		FlxG.mouse.visible = false;
		
		//FlxG.scaleMode = new RatioScaleMode(true); //@TODO: I'd like to use this, but it breaks the HUD currently -- need to position HUD elements based on distance from edges of screen
	}
	
	/** -----------------------------------------------------------------
	 *  Called whenever game window is resized
	 *  ----------------------------------------------------------------- */	
	override function onResize(Width:Int, Height:Int):Void
	{	
		super.onResize(Width, Height);
		
		// Attempt to achieve a pixel-perfect 2.0 zoom level based on game and window width
		FlxG.camera.zoom = ( (FlxG.width / FlxG.stage.stageWidth) * 2 );
		//trace("New zoom after resize: "+FlxG.camera.zoom);
		
		//trace(FlxG.stage.width); // why do these 2 report higher values when I zoom in, and lower on zoom out?!
		//trace(FlxG.game.width);
		
		//trace(FlxG.width); // game resolution (doesn't change)
		//trace(FlxG.stage.stageWidth); // window resolution
	}
	
	/** -----------------------------------------------------------------
	 *  Adds all created assets to the state in the desired Z-order
	 *  ----------------------------------------------------------------- */	
	private function addGameAssetsToState():Void
	{
		Reg.mapLoader.addBackgroundObjects(this);


		add( rockets );
		
		player.addToState();
		
		Reg.mapLoader.addForegroundObjects(this);
		
		player.addCrosshairLine();
		
		// Custom mouse cursor
		_crosshair = new FlxSprite( 0, 0, AssetPaths.cursor__png );
		_crosshair.scrollFactor.set( 0, 0 );
	//	add( _crosshair );

		add( Reg.HUD );
		
		FlxG.sound.volume = 0.2; //@TODO: Seems to be a bug where the first sound effect is very loud for a fraction of a second. Play a null.wav to fix?
	}
	




	
	/** --------------------------------------------------------------------
	 *  Handles camera zoom and ensures it stays within the games parameters
	 *  -------------------------------------------------------------------- */
	private function handleCameraZoom( targetZoom:Float ):Void
	{
		var newzoom = Reg.Clamp( targetZoom, CAM_ZOOM_MIN, CAM_ZOOM_MAX );
		FlxG.camera.zoom = newzoom;
	}

	

	
	/** ------------------------------------------
	 *  Function that is called once every frame.
	 *  ------------------------------------------ */
	override public function update(elapsed:Float):Void
	{
		// Mousewheel camera zoom
		if ( FlxG.mouse.wheel != 0 && !player.levelBeat )
		{
			handleCameraZoom( FlxG.camera.zoom + (FlxG.mouse.wheel * 0.1) );
		}
		
		// if we beat the level, do a zoom in effect
		if ( player.levelBeat )
		{
			var newzoom = Reg.Lerp( FlxG.camera.zoom, CAM_ZOOM_MAX, 0.025 );
			
			if ( newzoom < CAM_ZOOM_MAX )
			{
				handleCameraZoom( newzoom );
			}
		}
		else
		{
			// Vertical velocity-based automatic zooming (makes people sick, disabled)
/*			if(player.velocity.y > 260) //falling
				handleCameraZoom(FlxG.camera.zoom + 0.0125); //@TODO: these don't seem to be fps independant. Actually I bet a lot of this project isn't.. how do I get deltatime? -- "FlxG.elapsed"...but only relevant with non-fixed timestep!!
			else if(player.velocity.y < -260) //rising
				handleCameraZoom(FlxG.camera.zoom - 0.02);
			else if(player.velocity.y == 0)
				handleCameraZoom( Reg.Lerp( FlxG.camera.zoom, 2, 0.05 ) );*/
		}
			
#if (!flash && !html5)
		if ( FlxG.keys.justPressed.ESCAPE )
			Sys.exit(0);
#end
		
		if ( player.usingMouse )
			_crosshair.setPosition( Math.ceil(FlxG.mouse.screenX - _crosshair.width / 2), Math.ceil(FlxG.mouse.screenY - _crosshair.height / 2) );
		else
			_crosshair.setPosition( player.getScreenPosition().x + player.crosshairLocation.x ,//- _crosshair.width / 2,
										player.getScreenPosition().y + player.crosshairLocation.y );// - _crosshair.height / 2);
		
		// Update crosshair line to player
		var xhairScreenCenter:FlxPoint = FlxPoint.get( _crosshair.getScreenPosition().x + _crosshair.width / 2, _crosshair.getScreenPosition().y + _crosshair.height / 2 );
		var playerShootScreenCenter:FlxPoint = FlxPoint.get( player.getScreenPosition().x + player.width / 2 , player.getScreenPosition().y + player.height / 2 - Reg.PLAYER_SHOOT_Y_OFFSET + 2 );
		player.crosshairLine.setPosition( xhairScreenCenter.x, xhairScreenCenter.y );
		player.crosshairLine.origin.set( 0, 0 );
		
		var angle = playerShootScreenCenter.angleBetween( xhairScreenCenter );
		player.crosshairLine.angle = angle;
		
		var distance:Float = xhairScreenCenter.distanceTo( playerShootScreenCenter );
		
		player.crosshairLine.scale.y = Reg.RemapValClamped( distance, 150, 20, 1.0, 0.0 );
		player.crosshairLine.alpha = Reg.RemapValClamped( distance, 100, 20, 1.0, 0.0 );
		
		super.update(elapsed); // Needs to be called before player collides with map for correct velocity reporting
		
		if ( Reg.levelTimerStarted )
		{
			Reg.gameTimerStarted = true;
			
			Reg.levelTimer += elapsed;
		}
		
		if ( Reg.gameTimerStarted )
		{
			Reg.gameTimer += elapsed;
		}
		
		Reg.HUD.levelTimerText.text = "Level time: " + Std.int(Reg.levelTimer * 1000) / 1000;
		Reg.HUD.gameTimerText.text = "Total time: " + Std.int(Reg.gameTimer * 10) / 10;
		
		if ( player.living )
		{
			if ( Reg.HUD.deadText.alive )
				Reg.HUD.deadText.kill();

			Reg.mapLoader.handlePlayerOverlaps(player);
		}
		else
		{
			Reg.HUD.deadText.revive();
			FlxG.camera.follow( null );
		}
		
		// Allow the player to just reload the current level completely
		if ( FlxG.keys.justPressed.Y )
		{
			reloadPlayState();
		}
		
		if ( FlxG.keys.justPressed.P )
		{
			loadNextLevel();
		}
	}
	
	private function loadNextLevel():Void
	{
		if ( Reg.levelnum < Reg.levelnames.length - 1 )
		{
			Reg.levelnum++;
		}
		else
		{
			Reg.levelnum = 0;
		}
		
		reloadPlayState();
	}
	
	private function reloadPlayState():Void
	{
		player.levelBeat = false;
		Reg.destroyRockets(true);
		FlxG.switchState(new PlayState());
		
		Reg.resetTimers();
	}
	
	/**
	 * Function that is called when this state is destroyed - you might want to 
	 * consider setting all objects this state uses to null to help garbage collection.
	 */
	override public function destroy():Void
	{
		Reg.mapLoader = null;
		Reg.HUD = null;
		
		//@TODO: follow the advice and set stuff null here.
		super.destroy();
	}
}
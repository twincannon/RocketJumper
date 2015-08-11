package;

import entities.Goal;
import entities.Rocket;
import entities.Sign;
import flash.events.Event;
import flixel.addons.editors.tiled.TiledLayer;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.tile.FlxTile;
import flixel.tile.FlxTilemap;
import flixel.ui.FlxButton;
import flixel.FlxObject;
import flixel.math.FlxPoint;
import haxe.xml.Fast;
import haxe.io.Path;
import openfl.Assets;
import entities.Player;
import flixel.math.FlxRect;
import flixel.group.FlxGroup;
import flixel.addons.editors.ogmo.FlxOgmoLoader;
import entities.Checkpoint;
import flixel.util.FlxColor;
import flixel.math.FlxAngle;
import flixel.addons.tile.FlxTilemapExt;

import flixel.addons.editors.tiled.TiledMap;
import flixel.addons.editors.tiled.TiledObject;
import flixel.addons.editors.tiled.TiledObjectLayer;
import flixel.addons.editors.tiled.TiledTileSet;

/**
 * A FlxState which can be used for the actual gameplay.
 */
class PlayState extends FlxState
{
	public var backgroundTiles:FlxTypedGroup<FlxSprite> = new FlxTypedGroup<FlxSprite>();
	private var checkpoints:FlxTypedGroup<Checkpoint> = new FlxTypedGroup<Checkpoint>();
	private var signs:FlxTypedGroup<Sign> = new FlxTypedGroup<Sign>();
	private var goal:Goal;
	private var map:FlxTilemapExt;
	private var ooze:FlxTilemap;
	private var mapbg:FlxTilemap;
	private var detailmap:FlxTilemap;
	private var m_sprCrosshair:FlxSprite;
	private var hud:HUD;
	private var tiledMap:TiledMap;
	
	private static inline var camMinZoom:Float = 1.0;
	private static inline var camMaxZoom:Float = 4.0;
	private var camVelZoomOffset:Float = 0.0;
	private static inline var CAM_VEL_ZOOM_OFFSET_MAX:Float = 1.0;
	private var camZoomWhenLevelBeat:Float = 0;
	private var camLevelBeatTimeElapsed:Float = 0;
	
	/**
	 * Function that is called up when to state is created to set it up. 
	 */
	override public function create():Void
	{
		super.create();
		
		if ( Reg.worldCam != null )
			Reg.worldCam.destroy;
		
		FlxG.cameras.reset();
		
		Reg.worldCam = new FlxCamera( 0, 0, FlxG.width, FlxG.height, 1 );
		
		FlxG.cameras.add(Reg.worldCam);
		FlxG.camera = Reg.worldCam;
		
		hud = new HUD( FlxG.stage.stageWidth, FlxG.stage.stageHeight );
		
		setupLevel();
		
		//create and add entities
		Reg.player = new Player();
		goal = new Goal();
		
		loadEntities();
		add(goal);
		add(checkpoints);
		add(signs);
		add(Reg.player);
		Reg.player.addFireEffect(); //add fireeffect after player for proper z-ordering
		
		//custom mouse cursor
		m_sprCrosshair = new FlxSprite( 0, 0, AssetPaths.cursor__png );
		m_sprCrosshair.scrollFactor.set(0, 0);
		m_sprCrosshair.camera = Reg.worldCam;
		FlxG.mouse.visible = false;
		add( m_sprCrosshair );
		
	//	FlxG.camera.follow(Reg.player, FlxCamera.STYLE_LOCKON, 0.0/*0.5*/);
	//	FlxG.camera.deadzone = FlxRect.get( FlxG.width / 2, FlxG.height / 2 - 40, 0, 50 ); //causes weird issues with horizontal pixel lines?? see http://i.imgur.com/FHGaahO.gif
	//	FlxG.updateFramerate = 60; //....apparently this isnt kosher? cant be lower than draw framerate? Wtf
		
		FlxG.worldBounds.set(0, 0, tiledMap.fullWidth, tiledMap.fullHeight);
		//FlxG.camera.setBounds(0, 0, tiledMap.fullWidth, tiledMap.fullHeight);	
		
		add(hud);
		
		Reg.worldCam.follow(Reg.player, FlxCameraFollowStyle.LOCKON, FlxPoint.get(0,0), 5);
		
		onResize( FlxG.stage.stageWidth, FlxG.stage.stageHeight );
		handleCameraZoom(2);
	}
	
	function getStartGid(tiledLevel:TiledMap, tilesheetName:String):Int
	{
		var tileGID:Int = 1;
		
		for (tileset in tiledLevel.tilesets)
		{
			var tilesheetPath:Path = new Path(tileset.imageSource);
			var thisTilesheetName = tilesheetPath.file + "." + tilesheetPath.ext;
			
			if (thisTilesheetName == tilesheetName)
			{
				tileGID = tileset.firstGID;
			}
		}
		 
		return tileGID;
	}
	
	private function setupLevel():Void
	{
		if ( !Reg.levelsloaded )
		{
			Reg.levelsloaded = true;
			var xml = Xml.parse(Assets.getText("assets/data/levels.xml"));
			var fast = new haxe.xml.Fast(xml.firstElement());
			var levels = fast.node.levels;
			for ( l in levels.nodes.level )
			{
				Reg.levelnames.push(l.innerData);
				Reg.leveltitles.push(l.att.name);
			}
		}
		
		//WARNING: if you put a tile in the wrong layer (i.e. tilesbg in tiles), it causes a crash (?!) probably array indices error, which is silly
		
		tiledMap = new TiledMap( "assets/data/" + Reg.levelnames[Reg.levelnum] );
		
		
		mapbg = new FlxTilemap();
		/*mapbg.widthInTiles = tiledMap.width;
		mapbg.heightInTiles = tiledMap.height;
		mapbg.loadMap( tiledMap.getLayer("tilesbg").tileArray, "assets/images/tilesbg.png", 20, 20, FlxTilemap.OFF, getStartGid(tiledMap, "tilesbg.png") );*/
		mapbg.loadMapFromArray( tiledMap.getLayer("tilesbg"), tiledMap.width, tiledMap.height, "assets/images/tilesbg.png", 20, 20, FlxTilemapAutoTiling.OFF, getStartGid(tiledMap, "tilesbg.png") );
		mapbg.loadMapFromCSV( tiledMap.getLayer("tiles"), "assets/images/tilesbg.png", 20, 20, FlxTilemapAutoTiling.OFF, getStartGid(tiledMap, "tilesbg.png") );
		
		tiledMap.getLayer("tiles")
		
		
		
		map = new FlxTilemapExt();
		/*map.widthInTiles = tiledMap.width;
		map.heightInTiles = tiledMap.height;
		map.loadMap( tiledMap.getLayer("tiles").tileArray, "assets/images/tiles.png", 20, 20, FlxTilemap.OFF, getStartGid(tiledMap, "tiles.png") );*/
	//	map.loadMapFromArray( tiledMap.getLayer("tiles").map.tilesetArray, tiledMap.width, tiledMap.height, "assets/images/tiles.png", 20, 20, FlxTilemapAutoTiling.OFF, getStartGid(tiledMap, "tiles.png") );
		map.loadMapFromCSV( tiledMap.getLayer("tiles"), "assets/images/tiles.png", 20, 20, FlxTilemapAutoTiling.OFF, getStartGid(tiledMap, "tiles.png") );
		
		var tempFL:Array<Int> = [34,46];
		var tempFR:Array<Int> = [33,45];
		var tempCL:Array<Int> = [36,48];
		var tempCR:Array<Int> = [35,47];
		map.setSlopes(tempFL, tempFR, tempCL, tempCR);
		
		detailmap = new FlxTilemap();
		/*detailmap.widthInTiles = tiledMap.width;
		detailmap.heightInTiles = tiledMap.height;
		detailmap.loadMap( tiledMap.getLayer("tilesdetail").tileArray, "assets/images/tilesdetail.png", 20, 20, FlxTilemap.OFF, getStartGid(tiledMap, "tilesdetail.png") );*/
		//detailmap.loadMapFromArray( tiledMap.getLayer("tilesdetail").map.tilesetArray, tiledMap.width, tiledMap.height, "assets/images/tilesdetail.png", 20, 20, FlxTilemapAutoTiling.OFF, getStartGid(tiledMap, "tilesdetail.png") );
		detailmap.loadMapFromCSV( tiledMap.getLayer("tiles"), "assets/images/tilesdetail.png", 20, 20, FlxTilemapAutoTiling.OFF, getStartGid(tiledMap, "tilesdetail.png") );
		
		ooze = new FlxTilemap();
		/*ooze.widthInTiles = tiledMap.width;
		ooze.heightInTiles = tiledMap.height;
		ooze.loadMap( tiledMap.getLayer("ooze").tileArray, "assets/images/tiles_ooze.png", 20, 20, FlxTilemap.OFF, getStartGid(tiledMap, "tiles_ooze.png") );*/
		//ooze.loadMapFromArray( tiledMap.getLayer("ooze").map.tilesetArray, tiledMap.width, tiledMap.height, "assets/images/tiles_ooze.png", 20, 20, FlxTilemapAutoTiling.OFF, getStartGid(tiledMap, "tiles_ooze.png") );
		ooze.loadMapFromCSV( tiledMap.getLayer("ooze"), "assets/images/tiles_ooze.png", 20, 20, FlxTilemapAutoTiling.OFF, getStartGid(tiledMap, "tiles_ooze.png") );
		
		/*hud.minimap.widthInTiles = tiledMap.width;
		hud.minimap.heightInTiles = tiledMap.height;
		hud.minimap.loadMap( tiledMap.getLayer("tiles").tileArray, "assets/images/tiles_minimap.png", 1, 1, FlxTilemap.OFF, getStartGid(tiledMap, "tiles.png" ));
		hud.minimapbg.widthInTiles = tiledMap.width;
		hud.minimapbg.heightInTiles = tiledMap.height;
		hud.minimapbg.loadMap( tiledMap.getLayer("tilesbg").tileArray, "assets/images/tilesbg_minimap.png", 1, 1, FlxTilemap.OFF, getStartGid(tiledMap, "tilesbg.png" ));*/
		
#if !flash
		//damn -- this doesn't seem to solve the vertical tearing issue -- it's actually neighboring tiles bleeding into other tiles (i.e. the dirt block bleeding into the black block)
		/*mapbg.tileScaleHack = 1.02;
		map.tileScaleHack = 1.02;
		detailmap.tileScaleHack = 1.02;
		ooze.tileScaleHack = 1.02;
		ooze.useScaleHack = true;*/ //this is updated in 4.0.0 maybe its fixed!!
#end
		
		mapbg.camera = Reg.worldCam;
		map.camera = Reg.worldCam;
		detailmap.camera = Reg.worldCam;
		ooze.camera = Reg.worldCam;
		
		mapbg.allowCollisions = FlxObject.NONE;
		detailmap.allowCollisions = FlxObject.NONE;
		
		var bgW = 303;
		var bgH = 256;
		
		//@TODO make 4 of these in a classic scrolling bg style instead of making way too many to cover the map
		//also maybe make a different background type for some levels
		for (i in -1...6)
		{
			for (j in -1...4)
			{
				var bgtile = new FlxSprite( i * bgW, j * bgH, "assets/images/background.png" );
				bgtile.scrollFactor.x = bgtile.scrollFactor.y = 0.2;
				bgtile.width = 0;
				bgtile.height = 0;
				bgtile.allowCollisions = FlxObject.NONE;
				bgtile.pixelPerfectRender = Reg.shouldPixelPerfectRender;
				bgtile.camera = Reg.worldCam;
				backgroundTiles.add(bgtile);
			}
		}
		
		add(backgroundTiles);
		Reg.mapGroup = new FlxGroup();
		Reg.mapGroup.add( mapbg );
		Reg.mapGroup.add( map );
		Reg.mapGroup.add( detailmap );
		Reg.mapGroup.add( ooze );
		add( Reg.mapGroup );
	}
	
	override public function onResize(Width:Int, Height:Int):Void
	{
		//the hud camera doesn't resize correctly here but I've tried absolutely everything.
		hud.updateSizes( 0, 0, Width, Height );		
		handleCameraZoom( Width / FlxG.camera.width );
	}
	
	private function handleCameraZoom( targetZoom:Float ):Void
	{
		var W:Int = FlxG.stage.stageWidth;
		var H:Int = FlxG.stage.stageHeight;
		
		//TODO: handle updated camera bounds...
		
		//TODO: make it handle deadzones ....
		
		var calcMaxZoom = camMaxZoom * ( W / FlxG.camera.width );
		var calcMinZoom = camMinZoom * ( W / FlxG.camera.width );
		
		var newzoom = Reg.Clamp( targetZoom, calcMinZoom, calcMaxZoom );
		
		if ( FlxG.camera.zoom != newzoom )
		{
			FlxG.camera.zoom = newzoom;
			
			var basezoom = W / FlxG.camera.width; //2
			var offsetamt = basezoom - newzoom;
			FlxG.camera.x = offsetamt * (FlxG.camera.width / basezoom) * basezoom / 2;
			FlxG.camera.y = offsetamt * (FlxG.camera.height / basezoom) * basezoom / 2;

			//@TODO make a proper bounds offset..... this isnt right.
			var boundsOffsetX = FlxG.camera.x;
			var boundsOffsetY = FlxG.camera.y;
		//	FlxG.camera.setBounds( boundsOffsetX, boundsOffsetY, tiledMap.fullWidth - boundsOffsetX*2, tiledMap.fullHeight - boundsOffsetY*2);	
		}		
	}
	
	private function loadEntities():Void
	{
		for ( group in tiledMap.objectGroups )
		{
			for ( o in group.objects )
			{
				var x:Int = o.x;
				var y:Int = o.y;
				
				if ( o.gid != -1 )
					y -= group.map.getGidOwner(o.gid).tileHeight;
					
				switch ( o.type.toLowerCase() )
				{
					case "player":
						Reg.player.x = x;
						Reg.player.y = y;
						Reg.player.originalSpawnPoint = FlxPoint.get( x, y );
						Reg.player.spawnPoint = FlxPoint.get( x, y );
					case "goal":
						goal.x = x;
						goal.y = y;
						goal.setSize( 20, 40 ); //@TODO parameterize these somewhere
					case "checkpoint":
						var num:Int = 0;
						if ( o.xmlData.hasNode.properties )
							if ( o.xmlData.node.properties.hasNode.property )
								num = Std.int( Std.parseFloat( o.xmlData.node.properties.node.property.att.value ) );
						var w:Int = o.width;
						var h:Int = o.height;
						var chkpt = new Checkpoint( x, y, w, h, num );
						checkpoints.add( chkpt );
					case "sign":
						var signtext:String = "";
						if ( o.xmlData.hasNode.properties )
							if ( o.xmlData.node.properties.hasNode.property )
								signtext = StringTools.replace( o.xmlData.node.properties.node.property.att.value, "\\n", "\n" );
						var sign = new Sign( x, y, signtext );
						signs.add(sign);
				}
			}
		}
	}
		
	/**
	 * Function that is called once every frame.
	 */
	override public function update(elapsed:Float):Void
	{
		// if player resurrected() is called while level is beat, we need to reset zoom stuff
		if ( Reg.playerReset )
		{
			camZoomWhenLevelBeat = 0;
			camLevelBeatTimeElapsed = 0;
			handleCameraZoom( FlxG.stage.stageWidth / FlxG.camera.width );
			
			Reg.playerReset = false;
		}
		
		//@TODO ok flxg.mouse.wheel doesn't work in cpp target anymore? "FLX_MOUSE_ADVANCED" ?
		// check for camera zoom
		if ( FlxG.mouse.wheel != 0 && !Reg.player.levelBeat )
		{
			handleCameraZoom( FlxG.camera.zoom + (FlxG.mouse.wheel * 0.1) );
		}
		
		// if we beat the level, do a zoom in effect
		if ( Reg.player.levelBeat )
		{
			if ( camZoomWhenLevelBeat == 0 )
				camZoomWhenLevelBeat = FlxG.camera.zoom;
			
			var calcMaxZoom = camMaxZoom * ( FlxG.stage.stageWidth / FlxG.camera.width );
			var newzoom = Reg.Lerp( camZoomWhenLevelBeat, calcMaxZoom, camLevelBeatTimeElapsed / 1.5 );
			
			if ( newzoom < calcMaxZoom - 1.0 )
			{
				handleCameraZoom( newzoom );
				camLevelBeatTimeElapsed += elapsed;
			}
		}
		else
		{
		//	var oldzoom = FlxG.camera.zoom;
		//	var newzoom = Reg.Lerp( oldzoom, CAM_VEL_ZOOM_OFFSET_MAX, 5 );
			
			if(Reg.player.velocity.y > 260) //falling
				handleCameraZoom(FlxG.camera.zoom + 0.0125); //@TODO: these don't seem to be fps independant. Actually I bet a lot of this project isn't.. how do I get deltatime? -- "FlxG.elapsed"...but only relevant with non-fixed timestep!!
			else if(Reg.player.velocity.y < -260) //rising
				handleCameraZoom(FlxG.camera.zoom - 0.02);
			else if(Reg.player.velocity.y == 0)
				handleCameraZoom( Reg.Lerp( FlxG.camera.zoom, 2, 0.05 ) );
		}
			
#if !flash
		if ( FlxG.keys.justPressed.ESCAPE )
			Sys.exit(0);
#end
		
		if ( Reg.player.usingMouse )
			m_sprCrosshair.setPosition( Math.ceil(FlxG.mouse.screenX - m_sprCrosshair.width / 2), Math.ceil(FlxG.mouse.screenY - m_sprCrosshair.height / 2) );
		else
			m_sprCrosshair.setPosition( Reg.player.getScreenPosition().x + Reg.player.crosshairLocation.x ,//- m_sprCrosshair.width / 2,
										Reg.player.getScreenPosition().y + Reg.player.crosshairLocation.y );// - m_sprCrosshair.height / 2);
		
		// Update crosshair line to player
		var xhairScreenCenter:FlxPoint = FlxPoint.get( m_sprCrosshair.getScreenPosition().x + m_sprCrosshair.width / 2, m_sprCrosshair.getScreenPosition().y + m_sprCrosshair.height / 2 );
		var playerShootScreenCenter:FlxPoint = FlxPoint.get( Reg.player.getScreenPosition().x + Reg.player.width / 2 , Reg.player.getScreenPosition().y + Reg.player.height / 2 - Reg.PLAYER_SHOOT_Y_OFFSET + 2 );
		Reg.player.crosshairLine.setPosition( xhairScreenCenter.x, xhairScreenCenter.y );
		Reg.player.crosshairLine.origin.set( 0, 0 );
		
		var angle = playerShootScreenCenter.angleBetween( xhairScreenCenter );
		Reg.player.crosshairLine.angle = angle;
		
		var distance:Float = xhairScreenCenter.distanceTo( playerShootScreenCenter );
		
		Reg.player.crosshairLine.scale.y = Reg.RemapValClamped( distance, 150, 20, 1.0, 0.0 );
		Reg.player.crosshairLine.alpha = Reg.RemapValClamped( distance, 100, 20, 1.0, 0.0 );
		
		super.update(elapsed);
		
		if ( Reg.gameTimerStarted )
			Reg.gameTimer += FlxG.elapsed;
		
		hud.timerText.text = "Time: " + Std.int(Reg.player.levelTimer*1000) / 1000;
		
		if ( Reg.player.living )
		{
			if ( hud.deadText.alive )
				hud.deadText.kill();
				
			FlxG.collide(map, Reg.player);
			
			//Don't let player leave the map (horizontally)
			if ( Reg.player.x < map.x )
				Reg.player.x = map.x;
			else if ( Reg.player.x + Reg.player.width > tiledMap.fullWidth )
				Reg.player.x = tiledMap.fullWidth - Reg.player.width;
			
			if ( Reg.player.y > tiledMap.fullHeight || Reg.player.y < map.y )
			{
				Reg.player.y = map.y;
				Reg.player.velocity.y = 0;
			}
			
			if ( FlxG.overlap( Reg.player, checkpoints, Reg.player.touchCheckpoint ) )
			{
				//is it safe to kill the checkpoint in player..?
			}
			
			if ( FlxG.overlap( Reg.player, goal ) )
				Reg.player.goalMet();
			
			var drawsigntext = false;

			if ( !Reg.player.levelBeat )
			{
				if ( ooze.overlapsWithCallback( Reg.player.innerHitbox,
												function(P:FlxObject, T:FlxObject) { return FlxG.overlap( P, T ); },
												true ) ) //the bool here makes this return the specific FlxTile to the function
				{
					Reg.player.melting = true;
				}
				else if ( FlxG.overlap( Reg.player, signs, function(P:FlxObject, S:Sign) { hud.signText.text = S.signText; return FlxG.overlap( P, S ); } ) )
				{
					hud.signTextBox.revive();
					hud.signText.revive();
				}
				else if ( hud.signText.alive )
				{
					hud.signTextBox.kill();
					hud.signText.kill();
				}
			}
						
			if ( Reg.player.levelBeat )
			{
				if ( Reg.levelnum < Reg.levelnames.length - 1 )
				{
					hud.levelFinishedText.text = "Goal! Hit [ENTER] or (Y) to go to next level!";
				}
				else
				{
					var s = Std.string( Reg.gameTimer );
					var i = s.indexOf( '.' );
					s = s.substr( 0, i + 4 );
					
					hud.levelFinishedText.text = "You beat all the levels! Nice work!\nTotal time: " + s + "\nHit [ENTER] or (Y) to play through it again.";
					Reg.gameTimerStarted = false;
				}
				hud.levelFinishedText.revive();
			}
			else if ( hud.levelFinishedText.alive )
				hud.levelFinishedText.kill();
		}
		else
		{
			hud.deadText.revive();
			FlxG.camera.follow( null );
		}
		
		if ( (FlxG.keys.justPressed.ENTER || Reg.player.gamepadTryNextLevel) && Reg.player.levelBeat )
		{
			Reg.player.gamepadTryNextLevel = false;
			
			if ( Reg.levelnum < Reg.levelnames.length - 1 )
			{
				Reg.levelnum++;
				FlxG.switchState(new PlayState());
			}
			else
			{
				Reg.levelnum = 0;
				Reg.gameTimer = 0;
			}
				
			Reg.player.levelBeat = false;
			Reg.destroyRockets();
			FlxG.switchState(new PlayState());
		}
	}
	
	/**
	 * Function that is called when this state is destroyed - you might want to 
	 * consider setting all objects this state uses to null to help garbage collection.
	 */
	override public function destroy():Void
	{
		//@TODO: follow the advice and set stuff null here.
		super.destroy();
	}
}
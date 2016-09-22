package;

import entities.Goal;
import entities.Prop;
import entities.Rocket;
import entities.Sign;
import entities.Coin;
import entities.Platform;
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
import flixel.tile.FlxBaseTilemap;
import flixel.ui.FlxButton;
import flixel.FlxObject;
import flixel.math.FlxPoint;
import haxe.xml.Fast;
import haxe.io.Path;
import openfl.Assets;
import entities.Player;
import flixel.math.FlxRect;
import flixel.group.FlxGroup;
import entities.Checkpoint;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.math.FlxAngle;
import flixel.addons.tile.FlxTilemapExt;
import flixel.graphics.frames.FlxTileFrames;
import flixel.effects.postprocess.PostProcess;

import flixel.addons.editors.tiled.TiledMap;
import flixel.addons.editors.tiled.TiledObject;
import flixel.addons.editors.tiled.TiledObjectLayer;
import flixel.addons.editors.tiled.TiledTileSet;
import flixel.addons.editors.tiled.TiledTileLayer;


/**
 * A FlxState which can be used for the actual gameplay.
 */
class PlayState extends FlxState
{
	public var backgroundTiles:FlxTypedGroup<FlxSprite> = new FlxTypedGroup<FlxSprite>();
	private var checkpoints:FlxTypedGroup<Checkpoint> = new FlxTypedGroup<Checkpoint>();
	private var signs:FlxTypedGroup<Sign> = new FlxTypedGroup<Sign>();
	private var coins:FlxTypedGroup<Coin> = new FlxTypedGroup<Coin>();
	private var propsBack:FlxTypedGroup<Prop> = new FlxTypedGroup<Prop>();
	private var propsMid:FlxTypedGroup<Prop> = new FlxTypedGroup<Prop>();
	private var propsFore:FlxTypedGroup<Prop> = new FlxTypedGroup<Prop>();
	private var goal:Goal;
	private var map:FlxTilemapExt;
	private var ooze:FlxTilemap;
	private var mapbg:FlxTilemap;
	private var detailmap:FlxTilemap;
	private var m_sprCrosshair:FlxSprite;
	private var hud:HUD;
	private var tiledMap:TiledMap;
	
	private var initialCamPanning:Bool = true;
	private var initialCamTarget:FlxObject;
	
	private static inline var camMinZoom:Float = 1.0;
	private static inline var camMaxZoom:Float = 4.0;
	private var camVelZoomOffset:Float = 0.0;
	private static inline var CAM_VEL_ZOOM_OFFSET_MAX:Float = 1.0;
	
	private var objectImageGIDs = new List<{ObjectGID:Int, ObjectFilename:String}>();
	
	/** -----------------------------------------------------------------
	 *  Function that is called up when to state is created to set it up. 
	 */
	override public function create():Void
	{
		super.create();
		
		if ( Reg.worldCam != null )
			Reg.worldCam.destroy;
		
		FlxG.cameras.reset();
		
		Reg.worldCam = new FlxCamera( 0, 0, FlxG.width, FlxG.height, 1 );
		
		FlxG.cameras.add( Reg.worldCam );
		FlxG.camera = Reg.worldCam;
	//	FlxG.camera.bgColor = 0xFF58533E;
		
		setupLevel();
		
		hud = new HUD( FlxG.width, FlxG.height );
		
		loadEntities();
		addGameAssetsToState();
		
		onResize( FlxG.stage.stageWidth, FlxG.stage.stageHeight );
		handleCameraZoom( 1 );
		Reg.worldCam.flash( FlxColor.BLACK, 0.75 );	
		
#if !flash
		var shader = new PostProcess("assets/shaders/scanline.frag");
		FlxG.addPostProcess(shader);
#end
	}
	
	function addGameAssetsToState():Void
	{
		add( propsBack );
		add( propsMid );
		
		add( Reg.mapGroup );
	//	addMapBorders( 0xFF0A0800 ); // Same color as the 'black' tile in the new tileset
		
		add( goal );
		add( checkpoints );
		add( signs );
		add( coins );
		add( Reg.rockets );
		
		Reg.player.addToState();
		
		add( map ); //TODO: find out if it's safe to add this twice? (just doing it for z-ordering) this object is also added via adding the reg.mapgroup
		add( propsFore );
		
		Reg.player.addCrosshairLine();
		
		//Custom mouse cursor
		m_sprCrosshair = new FlxSprite( 0, 0, AssetPaths.cursor__png );
		m_sprCrosshair.scrollFactor.set( 0, 0 );
		m_sprCrosshair.camera = Reg.worldCam;
		FlxG.mouse.visible = false;
		add( m_sprCrosshair );

		add( hud );
	}
	
	/** -------------------------------------------------------------------- 
	 *  Helper function to get the starting ID a tileset in a given TiledMap
	 */
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
	
	/** ----------------------------------------------------------------------------
	 *  Parses the level list if necessary and then loads the currently selected map
	 */
	private function setupLevel():Void
	{
		if ( !Reg.levelsloaded )
		{
			Reg.levelsloaded = true;
			var xml = Xml.parse(Assets.getText(Reg.ASSET_PATH_DATA + "levels.xml"));
			var fast = new haxe.xml.Fast(xml.firstElement());
			var levels = fast.node.levels;
			for ( l in levels.nodes.level )
			{
				Reg.levelnames.push(l.innerData);
				Reg.leveltitles.push(l.att.name);
			}
		}
		
		tiledMap = new TiledMap( Reg.ASSET_PATH_DATA + Reg.levelnames[Reg.levelnum] ); // NOTE: TiledMap.hx currently doesn't support "collection of image" tilesets, so check for "if(node.hasNode.image)" @ln 117 in TiledMap.hx to get around a crash here. (I just avoid loading these tilesets)
		
		// Load "props" tiles GID/filename associations
		var propsxml = Xml.parse( Assets.getText(Reg.ASSET_PATH_DATA + Reg.levelnames[Reg.levelnum]) );
		var propsfast = new haxe.xml.Fast( propsxml.firstElement() );
		
		for (Tileset in propsfast.nodes.tileset)
		{
			if (Tileset.att.name == "props")
			{
				var startgid:Int = Std.parseInt(Tileset.att.firstgid);
				
				for (Tile in Tileset.nodes.tile)
				{
					var curgid:Int = Std.parseInt(Tile.att.id);
					var filename:String = Tile.node.image.att.source;
					var cutoff = "../images/"; // Chop off this part from the filename
					
					var objectgid = curgid + startgid;
					var file = filename.substr(cutoff.length);
					
					var newitem = { ObjectGID:objectgid, ObjectFilename:file };
					objectImageGIDs.add(newitem);
				}
			}
		}
		
		// Create various tilemaps
		mapbg = new FlxTilemap();
		map = new FlxTilemapExt();
		ooze = new FlxTilemap();
		detailmap = new FlxTilemap();
		
		for ( layer in tiledMap.layers )
		{
			if ( !Std.is(layer, TiledTileLayer) )
				continue;
			
			var tileLayer = cast (layer, TiledTileLayer);
			
			if ( layer.name == "tilesbg" )
			{
				var borderedTiles = FlxTileFrames.fromBitmapAddSpacesAndBorders("assets/images/tilesbg.png", FlxPoint.get(20, 20), FlxPoint.get(2, 2));
				mapbg.loadMapFromCSV( tileLayer.csvData, borderedTiles, 20, 20, FlxTilemapAutoTiling.OFF, getStartGid(tiledMap, "tilesbg.png") );
			}
			else if ( layer.name == "tiles" )
			{
				var borderedTiles = FlxTileFrames.fromBitmapAddSpacesAndBorders("assets/images/tiles.png", FlxPoint.get(20, 20), FlxPoint.get(2, 2));
				map.loadMapFromCSV( tileLayer.csvData, borderedTiles, 20, 20, FlxTilemapAutoTiling.OFF, getStartGid(tiledMap, "tiles.png") );
			}
			else if ( layer.name == "ooze" )
			{
				var borderedTiles = FlxTileFrames.fromBitmapAddSpacesAndBorders("assets/images/tiles_ooze.png", FlxPoint.get(20, 20), FlxPoint.get(2, 2));
				ooze.loadMapFromCSV( tileLayer.csvData, borderedTiles, 20, 20, FlxTilemapAutoTiling.OFF, getStartGid(tiledMap, "tiles_ooze.png") );
			}
			
			else if ( layer.name == "tilesdetail" )
			{
				var borderedTiles = FlxTileFrames.fromBitmapAddSpacesAndBorders("assets/images/tilesdetail.png", FlxPoint.get(20, 20), FlxPoint.get(2, 2));
				detailmap.loadMapFromCSV( tileLayer.csvData, borderedTiles, 20, 20, FlxTilemapAutoTiling.OFF, getStartGid(tiledMap, "tilesdetail.png") );
			}
		}
		
		var tempFL:Array<Int> = [34,46]; //tilesnew: 3
		var tempFR:Array<Int> = [33,45]; //tilesnew: 2
		var tempCL:Array<Int> = [36,48]; //tilesnew: 5
		var tempCR:Array<Int> = [35,47]; //tilesnew: 4
		map.setSlopes(tempFL, tempFR, tempCL, tempCR);	
		
		//map.color = 0x333333; // this basically multiplies the base color, so instead of having a separate dark tilemap for tilesbg, i could just use this for tiles.png
		
		mapbg.camera = Reg.worldCam;
		detailmap.camera = Reg.worldCam;
		map.camera = Reg.worldCam;
		ooze.camera = Reg.worldCam;
		
		
		
		
		
		
		
		
		
		for (i in -1...16)
  		{
  			for (j in -1...14)
  			{
				var bgW = 303;
				var bgH = 256;
 				var bgtile = new FlxSprite( i * bgW, j * bgH, "assets/images/background.png" );
 				bgtile.scrollFactor.x = bgtile.scrollFactor.y = 0.9;
 				bgtile.width = 0;
 				bgtile.height = 0;
 				bgtile.allowCollisions = FlxObject.NONE;
 				bgtile.pixelPerfectRender = Reg.shouldPixelPerfectRender;
  				bgtile.camera = Reg.worldCam;
  				backgroundTiles.add(bgtile);
  			}
		}
		add(backgroundTiles);
		
		
		
		
		
		mapbg.allowCollisions = FlxObject.NONE;
		
		detailmap.allowCollisions = FlxObject.NONE;
		
		Reg.mapGroup = new FlxGroup();
		Reg.mapGroup.add( mapbg );
		Reg.mapGroup.add(detailmap);
		Reg.mapGroup.add( ooze );
		Reg.mapGroup.add( map );		
		
		// Sets the camera target to the center of the level TODO: Change this to use a target object (also, this doesn't need to be here)
		initialCamTarget = new FlxObject(map.x + map.width * 0.5, map.y + map.height * 0.5);
		Reg.worldCam.follow(initialCamTarget, FlxCameraFollowStyle.LOCKON, 5);
		
		FlxG.worldBounds.set(0, 0, tiledMap.fullWidth, tiledMap.fullHeight);
	}

	override public function onResize(Width:Int, Height:Int):Void
	{
		handleCameraZoom( Width / FlxG.camera.width );
	}
	
	private function handleCameraZoom( targetZoom:Float ):Void
	{
		var newzoom = Reg.Clamp( targetZoom, camMinZoom, camMaxZoom );
		FlxG.camera.zoom = newzoom;
	}
	
	/** -------------------------------------------------------------------------------------
	 *  Creates and loads requisite data from the tilemap for all entities present in the map
	 */
	private function loadEntities():Void
	{
		//create and add entities
		Reg.player = new Player();
		goal = new Goal();
		Reg.platforms = new FlxGroup();
		
		for (layer in tiledMap.layers)
		{
			if (Type.enumEq(layer.type, TiledLayerType.TILE)) continue;
			var objectLayer:TiledObjectLayer = cast layer; 
			
			for (o in objectLayer.objects)
			{
				var x:Int = o.x;
				var y:Int = o.y;
				
				switch ( o.type.toLowerCase() )
				{
					case "player":
						var startY:Float = o.y + o.height - Reg.player.height; // Put the player's feet at the bottom of the spawn object
						Reg.player.x = x;
						Reg.player.y = startY;
						Reg.player.originalSpawnPoint = FlxPoint.get( x, startY );
						Reg.player.spawnPoint = FlxPoint.get( x, startY );
					case "goal":
						goal.x = x;
						goal.y = y;
						goal.setSize( 20, 40 );
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
					case "coin":
						var coin = new Coin( x, y );
						coins.add(coin);
					case "platform":
						var platform = new Platform( x, y, o.width );
						Reg.platforms.add(platform);
						Reg.mapGroup.add(platform); // for rocket collisions
					default: // Environment props/decals
						var filename:String = "error.png";
						var flipX = false;
						var flipY = false;

#if neko
						// Neko doesn't handle unsigned ints correctly so here's an absurd hack. Note for all these clauses, if unsigned int simply worked, I could just use the TiledObject.gid variable...
						var nekoIntHack:Float = Std.parseFloat(o.xmlData.att.gid);
						var LONG_MAX:Float = 2147483648;
						
						if ( nekoIntHack > LONG_MAX )
						{
							nekoIntHack -= LONG_MAX;
							flipX = true;
							
							if ( nekoIntHack > LONG_MAX/2 )
							{
								nekoIntHack -= LONG_MAX/2; 
								flipY = true;
							}
						}
						
						var GIDNoFlags = Std.int(nekoIntHack);
#elseif !flash
						var GIDNoFlags:UInt = Std.int(Std.parseFloat(o.xmlData.att.gid)); // I don't want to explain this, just accept the fact that it exists and let's all move on with our lives
						// Ok I'm explaining this. The above is a hack to work on Windows. Neko (which I'm not even sure I should care about) doesn't work with this hack.
						// In attempting to fix this for Neko support, I found the core issue: this GID can be > a LONG_MAX, and the gid value itself is stored as just an Int.
						// The solution is to make support for 64 bit (or figure out why it needs to use -1 sometimes) for TiledObject.gid variable. (which is what I should be using, not this att lookup)
#else
						var GIDNoFlags = Std.parseInt(o.xmlData.att.gid);
#end
						
						// first, let's use this unsigned int to check for our flipped flags (neko already handles this above)
						if ( (GIDNoFlags & (1 << 31)) == (1 << 31) )
						{
							flipX = true;
						}
						if ( (GIDNoFlags & (1 << 30)) == (1 << 30) )
						{
							flipY = true;
						}
						
						// then let's clear those flags, revealing the GID of the image that this object uses
						GIDNoFlags &= ~(1 << 30);
						GIDNoFlags &= ~(1 << 31);
						
						// find the right image file, and then create the prop
						for (object in objectImageGIDs)
						{
							if ( object.ObjectGID == GIDNoFlags )
								filename = object.ObjectFilename;
						}
						
						var prop = new Prop(x, y, o.width, o.height, flipX, flipY, o.angle, filename);
						
						// See if the prop has a "scrollx" property (for scrollFactor.x, i.e. parallax) and set it
						if ( o.xmlData.hasNode.properties )
						{
							for ( Property in o.xmlData.node.properties.nodes.property )
							{
								if ( Property.att.name == "scrollx" )
									prop.scrollFactor.x = Std.parseFloat(Property.att.value);
							}
						}
						
						if ( prop.scrollFactor.x < 1.0 )
						{
							propsBack.add(prop);
							prop.color = prop.color.getDarkened( Math.abs(prop.scrollFactor.x - 1) );
							//prop.scrollFactor.y = Reg.RemapValClamped(prop.scrollFactor.x, 0.0, 1.0, 0.75, 1.0); // TODO: not sure if I want this (slight vertical parallax based on horiz. parallax)
						}
						else if ( prop.scrollFactor.x == 1.0 )
						{
							propsMid.add(prop);
						}
						else
						{
							propsFore.add(prop);
						}
						
						if ( prop.scrollFactor.x != 1.0 )
						{
							// Offset the prop to account for it being far away from the default camera top-left
							// This makes it more accurate to what it looks like in Tiled when the player is vertically aligned with the prop
							var difference = (prop.x * prop.scrollFactor.x) - (prop.x);
							prop.x += difference;
							
							if (prop.scrollFactor.x > 1.0)
							{
								prop.x += prop.width * 0.25;
								prop.x -= Reg.worldCam.width * 0.25;
							}
							else
							{
								prop.x -= prop.width * 0.25;
								prop.x += Reg.worldCam.width * 0.25;
							}
						}
						
					//end switch statement
				}	
			}
		}
		
		propsBack.sort(sortByScrollX);
		propsFore.sort(sortByScrollX);
	}
	
	private inline function sortByScrollX(order:Int, s1:FlxSprite, s2:FlxSprite)
	{
		return FlxSort.byValues(order, s1.scrollFactor.x, s2.scrollFactor.x);
	}
	
	/** --------------------------------------------------------------------------------------------------------------------------------
	 *  Adds 750 unit wide borders to the map of the color defined, to prevent things like parallax sprites from scrolling out of bounds
	 */
	private function addMapBorders(BackgroundColor:FlxColor):Void 
	{
		var BORDERSIZE:Int = 750;
		var BorderNorth:FlxSprite = new FlxSprite(map.x - BORDERSIZE, map.y - BORDERSIZE);
		BorderNorth.makeGraphic(Std.int(BORDERSIZE * 2 + map.width), BORDERSIZE, BackgroundColor);
		add(BorderNorth);
		var BorderSouth:FlxSprite = new FlxSprite(map.x - BORDERSIZE, map.y + map.height);
		BorderSouth.makeGraphic(Std.int(BORDERSIZE * 2 + map.width), BORDERSIZE, BackgroundColor);
		add(BorderSouth);
		var BorderEast:FlxSprite = new FlxSprite(map.x + map.width, map.y);
		BorderEast.makeGraphic(BORDERSIZE, Std.int(map.height), BackgroundColor);
		add(BorderEast);
		var BorderWest:FlxSprite = new FlxSprite(map.x - BORDERSIZE, map.y);
		BorderWest.makeGraphic(BORDERSIZE, Std.int(map.height), BackgroundColor);
		add(BorderWest);
	}
	
	/** ------------------------------------------
	 *  Function that is called once every frame.
	 */
	override public function update(elapsed:Float):Void
	{
		// Mousewheel camera zoom
		if ( FlxG.mouse.wheel != 0 && !Reg.player.levelBeat && !initialCamPanning )
		{
			handleCameraZoom( FlxG.camera.zoom + (FlxG.mouse.wheel * 0.1) );
		}
		
		// if we beat the level, do a zoom in effect
		if ( Reg.player.levelBeat )
		{
			var newzoom = Reg.Lerp( FlxG.camera.zoom, camMaxZoom, 0.025 );
			
			if ( newzoom < camMaxZoom )
			{
				handleCameraZoom( newzoom );
			}
		}
		else
		{
			// Vertical velocity-based automatic zooming (makes people sick, disabled)
/*			if(Reg.player.velocity.y > 260) //falling
				handleCameraZoom(FlxG.camera.zoom + 0.0125); //@TODO: these don't seem to be fps independant. Actually I bet a lot of this project isn't.. how do I get deltatime? -- "FlxG.elapsed"...but only relevant with non-fixed timestep!!
			else if(Reg.player.velocity.y < -260) //rising
				handleCameraZoom(FlxG.camera.zoom - 0.02);
			else if(Reg.player.velocity.y == 0)
				handleCameraZoom( Reg.Lerp( FlxG.camera.zoom, 2, 0.05 ) );*/
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
		
		super.update(elapsed); // Needs to be called before player collides with map for correct velocity reporting
		
		if ( Reg.levelTimerStarted )
		{
			Reg.gameTimerStarted = true;
			
			if (initialCamPanning)
			{
				handleCameraZoom( Reg.Lerp( FlxG.camera.zoom, 2, 3 * elapsed ) );
				Reg.worldCam.follow(Reg.player, FlxCameraFollowStyle.LOCKON, 0.1);
				
				if (Reg.worldCam.zoom - 2 > -0.01)
				{
					handleCameraZoom(2);
					Reg.worldCam.follow(Reg.player, FlxCameraFollowStyle.LOCKON, 5);
					initialCamPanning = false;
				}
			}
			
			Reg.levelTimer += FlxG.elapsed;
		}
		
		if ( Reg.gameTimerStarted )
		{
			Reg.gameTimer += FlxG.elapsed;
		}
		
		hud.levelTimerText.text = "Level time: " + Std.int(Reg.levelTimer * 1000) / 1000;
		hud.gameTimerText.text = "Total time: " + Std.int(Reg.gameTimer * 10) / 10;
		
		if ( Reg.player.living )
		{
			if ( hud.deadText.alive )
				hud.deadText.kill();
				
			FlxG.collide(map, Reg.player);
			
			if ( FlxG.collide(Reg.platforms, Reg.player) )
				Reg.player.onPlatform = true;
			
			//Don't let player leave the map
			Reg.player.ConstrainToMap( map.x, map.y, tiledMap.fullWidth, tiledMap.fullHeight );
			
			// Handle player/checkpoint overlap @TODO: is it safe to kill the checkpoint in player..?
			FlxG.overlap( Reg.player, checkpoints, Reg.player.touchCheckpoint );
			
			if ( FlxG.overlap( Reg.player, goal ) )
				Reg.player.goalMet();

			if ( Reg.player.levelBeat == false )
			{
				if ( ooze.overlapsWithCallback( Reg.player.innerHitbox,
												function(P:FlxObject, T:FlxObject) { return FlxG.overlap( P, T ); },
												true ) ) //the bool here makes this return the specific FlxTile to the function
				{
					Reg.player.melting = true;
				}
				
				if ( FlxG.overlap( Reg.player, signs, function(P:FlxObject, S:Sign) { hud.ToggleSign(true, S.signText); return FlxG.overlap( P, S ); } ) )
				{
					// (Logic is handled in the overlap function)
				}
				else if ( hud.signText.alive )
				{
					hud.ToggleSign(false);
				}
				
				if ( hud.levelFinishedText.alive )
				{
					hud.levelFinishedText.kill();
				}
			}
			else
			{
				if ( Reg.levelnum < Reg.levelnames.length - 1 )
				{
					hud.levelFinishedText.text = "Goal! Press JUMP to go to the next level!";
				}
				else
				{
					var s = Std.string( Reg.gameTimer );
					var i = s.indexOf( '.' );
					s = s.substr( 0, i + 4 );
					
					hud.levelFinishedText.text = "You beat all the levels! Nice work!\nTotal time: " + s + "\nHit JUMP to play through it again.";
					Reg.gameTimerStarted = false;
				}
				
				if ( hud.levelFinishedText.alive == false )
				{
					hud.levelFinishedText.revive();
				}
				
				// Current level finished, change to next level
				if ( FlxG.keys.justPressed.ENTER || Reg.player.m_bJumpPressedThisFrame )
				{
					loadNextLevel();
				}
			}
		}
		else
		{
			hud.deadText.revive();
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
		Reg.player.levelBeat = false;
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
		//@TODO: follow the advice and set stuff null here.
		super.destroy();
	}
}
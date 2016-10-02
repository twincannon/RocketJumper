package;

import haxe.xml.Fast;
import openfl.Assets;

import entities.Player;
import entities.Checkpoint;
import entities.Goal;
import entities.Prop;
import entities.Rocket;
import entities.Sign;
import entities.Coin;
import entities.Platform;

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

import flixel.tile.FlxTilemap;
import flixel.tile.FlxBaseTilemap;
import flixel.graphics.frames.FlxTileFrames;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.editors.tiled.TiledMap;
import flixel.addons.editors.tiled.TiledLayer;
import flixel.addons.editors.tiled.TiledObjectLayer;
import flixel.addons.editors.tiled.TiledTileSet;
import flixel.addons.editors.tiled.TiledTileLayer;

using StringTools;

/**
 * A FlxState which can be used for the actual gameplay.
 */
class PlayState extends FlxState
{
	private static inline var CAM_ZOOM_MIN:Float = 1.0;
	private static inline var CAM_ZOOM_MAX:Float = 4.0;
	
	public var player:Player;
	public var mapGroup:FlxGroup = new FlxGroup();
	public var platforms:FlxGroup = new FlxGroup();
	public var rockets:FlxGroup = new FlxGroup();
	public var worldCam:FlxCamera;
	public var gameHUD:HUD;
	
	private var _checkpoints:FlxTypedGroup<Checkpoint> = new FlxTypedGroup<Checkpoint>();
	private var _signs:FlxTypedGroup<Sign> = new FlxTypedGroup<Sign>();
	private var _coins:FlxTypedGroup<Coin> = new FlxTypedGroup<Coin>();
	private var _propsBack:FlxTypedGroup<Prop> = new FlxTypedGroup<Prop>();
	private var _propsMid:FlxTypedGroup<Prop> = new FlxTypedGroup<Prop>();
	private var _propsFore:FlxTypedGroup<Prop> = new FlxTypedGroup<Prop>();
	private var _goal:Goal;
	
	private var _tilemapMain:RJ_TilemapExt;
	private var _tilemapOoze:FlxTilemap;
	private var _tilemapBackground:FlxTilemap;
	private var _tilemapDetail:FlxTilemap;
	private var _crosshair:FlxSprite;
	private var _tiledMap:TiledMap;
	private var _objectImageGIDs = new List<{ObjectGID:Int, ObjectFilename:String}>();
	
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
		
		setupLevel();
		
		gameHUD = new HUD( FlxG.width, FlxG.height ); // Note: Creates and adds a second camera to FlxG.cameras

		loadEntities();
		addGameAssetsToState();
		
		handleCameraZoom( 1.3333332 ); //720 (game resolution) divided by 1080 (monitor resolution) @TODO: Make this not magic numbered
		worldCam.flash( FlxColor.BLACK, 0.75 );	
		
#if (cpp || neko)
		var shader = new PostProcess("assets/shaders/scanline.frag");
		FlxG.addPostProcess(shader);
#end

		worldCam.follow(player, FlxCameraFollowStyle.LOCKON, 5);
	}

	/** -----------------------------------------------------------------
	 *  Adds all created assets to the state in the desired Z-order
	 *  ----------------------------------------------------------------- */	
	private function addGameAssetsToState():Void
	{
		add( _propsBack );
		
	//	addMapBorders( 0xFF0A0800 ); // Same color as the 'black' tile in the new tileset
		add(_tilemapBackground);
		add(_tilemapDetail);
		add(_tilemapOoze);
		add(platforms);
	
		add( _propsMid );
		
		add( _goal );
		add( _checkpoints );
		add( _signs );
		add( _coins );
		add( rockets );
		
		player.addToState();
		
		add(_tilemapMain);
		
		add( _propsFore );
		
		player.addCrosshairLine();
		
		// Custom mouse cursor
		_crosshair = new FlxSprite( 0, 0, AssetPaths.cursor__png );
		_crosshair.scrollFactor.set( 0, 0 );
		add( _crosshair );

		add( gameHUD );
		
		FlxG.sound.volume = 0.2; //@TODO: Seems to be a bug where the first sound effect is very loud for a fraction of a second. Play a null.wav to fix?
	}
	
	/** --------------------------------------------------------------
	 *  Helper function to find a given TiledTileSet within a TiledMap
	 *  -------------------------------------------------------------- */ 
	private function getTilesetByName(tiledLevel:TiledMap, tilesheetName:String):TiledTileSet
	{
		for (tileset in tiledLevel.tilesets)
		{
			if (tileset.name == tilesheetName)
			{
				return tileset;
			}
		}
		 
		return null;
	}

	/** ----------------------------------------------------------------------------------------------------
	 *  Check that all tiles in a tilemap are within valid bounds (no accidental tiles from a wrong tileset)
	 *  ---------------------------------------------------------------------------------------------------- */ 
	private function checkTiles(MapData:String, StartGid:Int, NumTiles:Int):Array<Int>
	{
		// path to map data file
		if (Assets.exists(MapData))
		{
			MapData = Assets.getText(MapData);
		}
		
		// Figure out the map dimensions based on the data string
		var _data:Array<Int> = new Array<Int>();
		var columns:Array<String>;
		
		var regex:EReg = new EReg("[ \t]*((\r\n)|\r|\n)[ \t]*", "g"); // Some Tiled csv data specific filtering
		var lines:Array<String> = regex.split(MapData);
		var rows:Array<String> = lines.filter(function(line) return line != "");
		
		var heightInTiles:Int = rows.length;
		var widthInTiles:Int = 0;
		
		var row:Int = 0;
		while (row < heightInTiles)
		{
			var rowString = rows[row];
			if (rowString.endsWith(","))
				rowString = rowString.substr(0, rowString.length - 1);
			columns = rowString.split(",");
			
			if (columns.length == 0)
			{
				heightInTiles--;
				continue;
			}
			if (widthInTiles == 0)
			{
				widthInTiles = columns.length;
			}
			
			var column = 0;
			while (column < widthInTiles)
			{
				//the current tile to be added:
				var columnString = columns[column];
				var curTile = Std.parseInt(columnString);
				
				if (curTile == null)
					throw 'String in row $row, column $column is not a valid integer: "$columnString"';
				
				// Ensure tile is within bounds: common causes for it going out of bounds is using the incorrect tileset on a layer (i.e. tilesbg on tiles),
				// or changing the width/height of the image and Tiled not picking it up in it's image source
				if ( curTile < 0 )
				{
					curTile = 0;
				}
				else if (curTile > 0 && curTile < StartGid)
				{
					trace("WARNING: Tile id " + curTile + " at " + column + "," + row + " is below valid tile bounds!");
					curTile = 0;
				}
				else if (curTile > NumTiles + StartGid - 1)
				{
					trace("WARNING: Tile id " + curTile + " at " + column + "," + row + " is above valid tile bounds!");
					curTile = NumTiles + StartGid - 1;
				}
				
				_data.push(curTile);
				column++;
			}
			
			row++;
		}
		
		return _data;
	}
	
	/** ----------------------------------------------------------------------------
	 *  Parses the level list if necessary and then loads the currently selected map
	 *  ---------------------------------------------------------------------------- */
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
		
		_tiledMap = new TiledMap( Reg.ASSET_PATH_DATA + Reg.levelnames[Reg.levelnum] ); // NOTE: TiledMap.hx currently doesn't support "collection of image" tilesets, so check for "if(node.hasNode.image)" @ln 117 in TiledMap.hx to get around a crash here. (I just avoid loading these tilesets)
		
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
					_objectImageGIDs.add(newitem);
				}
			}
		}
		
		// Create various tilemaps
		_tilemapBackground = new FlxTilemap();
		_tilemapMain = new RJ_TilemapExt();
		_tilemapOoze = new FlxTilemap();
		_tilemapDetail = new FlxTilemap();
		
		for ( layer in _tiledMap.layers )
		{
			if ( !Std.is(layer, TiledTileLayer) )
				continue;

			var tileLayer = cast(layer, TiledTileLayer);
			
			var tileWidth:Int = 20;
			var tileHeight:Int = 20;
			var tileSpacing:FlxPoint = FlxPoint.get(0, 0);
			var tileBorder:FlxPoint = FlxPoint.get(2, 2);

			var filename = layer.name + Reg.ASSET_EXT_IMAGE;
			var tilemapPath:String = Reg.ASSET_PATH_TILEMAPS + filename;
			
			var tileset:TiledTileSet = getTilesetByName(_tiledMap, layer.name);
			if ( tileset == null )
			{
				trace("Couldn't resolve tilemap! File: " + tilemapPath);
				continue;
			}

			if ( Assets.exists(tilemapPath) )
			{
				
				tileset.firstGID;
				var borderedTiles = FlxTileFrames.fromBitmapAddSpacesAndBorders(tilemapPath, FlxPoint.get(tileWidth, tileHeight), tileSpacing, tileBorder);
				var startGid = tileset.firstGID;
				var tileCount = tileset.numTiles;
				var checkedTiles:Array<Int> = checkTiles(tileLayer.csvData, startGid, tileset.numTiles);
				
				if ( layer.name == "tilesbg" )
				{
					_tilemapBackground.loadMapFromArray( checkedTiles, tileLayer.width, tileLayer.height, borderedTiles, tileWidth, tileHeight, FlxTilemapAutoTiling.OFF, startGid );
				}
				else if ( layer.name == "tiles" )
				{
					_tilemapMain.loadMapFromArray( checkedTiles, tileLayer.width, tileLayer.height, borderedTiles, tileWidth, tileHeight, FlxTilemapAutoTiling.OFF, startGid );
				}
				else if ( layer.name == "ooze" )
				{
					_tilemapOoze.loadMapFromArray( checkedTiles, tileLayer.width, tileLayer.height, borderedTiles, tileWidth, tileHeight, FlxTilemapAutoTiling.OFF, startGid );
				}
				else if ( layer.name == "tilesdetail" )
				{
					_tilemapDetail.loadMapFromArray( checkedTiles, tileLayer.width, tileLayer.height, borderedTiles, tileWidth, tileHeight, FlxTilemapAutoTiling.OFF, startGid );
				}
			}
		}
		
		// Sets slopes (index starts at 1 here, not 0!)
		var tempNW:Array<Int> = [34,46, 57,58,59,60];
		var tempNE:Array<Int> = [33,45];
		var tempSW:Array<Int> = [36,48];
		var tempSE:Array<Int> = [35,47];
		_tilemapMain.setSlopes(tempNW, tempNE, tempSW, tempSE); // These slopes work as such: the direction is perpindicular, facing from inside the collidable area out (so NW means the northwest area is empty)
		_tilemapMain.setGentle([58], [57]);
		_tilemapMain.setSteep([59], [60]);
		//_tilemapMain.color = 0x333333; // this basically multiplies the base color, so instead of having a separate dark tilemap for tilesbg, i could just use this and re-use tiles.png
		
		_tilemapBackground.allowCollisions = FlxObject.NONE;
		_tilemapDetail.allowCollisions = FlxObject.NONE;

		var backdrop:FlxBackdrop = new FlxBackdrop( "assets/images/background.png", 0.5, 0.5, true, true );
		add(backdrop);	
		
		mapGroup.add( _tilemapBackground );
		mapGroup.add( _tilemapDetail );
		mapGroup.add( _tilemapOoze );
		mapGroup.add( _tilemapMain );		
		
		FlxG.worldBounds.set(0, 0, _tiledMap.fullWidth, _tiledMap.fullHeight);
	}
	
	/** --------------------------------------------------------------------
	 *  Handles camera zoom and ensures it stays within the games parameters
	 *  -------------------------------------------------------------------- */
	private function handleCameraZoom( targetZoom:Float ):Void
	{
		var newzoom = Reg.Clamp( targetZoom, CAM_ZOOM_MIN, CAM_ZOOM_MAX );
		FlxG.camera.zoom = newzoom;
	}
	
	/** -------------------------------------------------------------------------------------
	 *  Creates and loads requisite data from the tilemap for all entities present in the map
	 *  ------------------------------------------------------------------------------------- */
	private function loadEntities():Void
	{
		for (layer in _tiledMap.layers)
		{
			if (Type.enumEq(layer.type, TiledLayerType.TILE)) continue; // Skip tile layers: we're looking for object layers
			var objectLayer:TiledObjectLayer = cast layer; 
			
			for (o in objectLayer.objects)
			{
				var x:Int = o.x;
				var y:Int = o.y;
				
				switch ( o.type.toLowerCase() )
				{
					case "player":
						player = new Player(x, y + o.height - Player.PLAYER_HEIGHT); // Create the player at the bottom of the spawn point
					case "goal":
						_goal = new Goal(x, y);
					case "checkpoint":
						var num:Int = 0;
						if ( o.xmlData.hasNode.properties )
							if ( o.xmlData.node.properties.hasNode.property )
								num = Std.int( Std.parseFloat( o.xmlData.node.properties.node.property.att.value ) );
						var w:Int = o.width;
						var h:Int = o.height;
						var chkpt = new Checkpoint( x, y, w, h, num );
						_checkpoints.add( chkpt );
					case "sign":
						var signtext:String = "";
						if ( o.xmlData.hasNode.properties )
							if ( o.xmlData.node.properties.hasNode.property )
								signtext = StringTools.replace( o.xmlData.node.properties.node.property.att.value, "\\n", "\n" );
						var sign = new Sign( x, y, signtext );
						_signs.add(sign);
					case "coin":
						var coin = new Coin( x, y );
						_coins.add(coin);
					case "platform":
						var platform = new Platform( x, y, o.width );
						platforms.add(platform);
						mapGroup.add(platform); // for rocket collisions
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
						for (object in _objectImageGIDs)
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
							_propsBack.add(prop);
							prop.color = prop.color.getDarkened( Math.abs(prop.scrollFactor.x - 1) );
							//prop.scrollFactor.y = Reg.RemapValClamped(prop.scrollFactor.x, 0.0, 1.0, 0.75, 1.0); // TODO: not sure if I want this (slight vertical parallax based on horiz. parallax)
						}
						else if ( prop.scrollFactor.x == 1.0 )
						{
							_propsMid.add(prop);
						}
						else
						{
							_propsFore.add(prop);
						}
						
						if ( prop.scrollFactor.x != 1.0 )
						{
							// Offset the prop to account for it being far away from the default camera top-left
							// This makes it more accurate to what it looks like in Tiled when the player is vertically aligned with the prop
							
							// This still isn't perfect but I spent a ton of hours getting it this close (all the props are slightly offset to the right based on scrollfactor)
							// For the future: the goal is to make it so props appear where they do in Tiled when the player is centered on top of their would-be location
							
							// Also, this is definitely based on the width of the prop: the wider it is, the worse the offset (also, the fact that the offset is always +x)
							var halfWidth:Float = worldCam.width * 0.5; //640
							prop.x -= ( prop.x - (prop.x * prop.scrollFactor.x) );
							prop.x += halfWidth - (halfWidth * prop.scrollFactor.x);
						}
						
					//end switch statement
				}	
			}
		}

		if ( player == null )
		{
			trace("Warning: Player start not found! Spawning player at 0, 0");
			player = new Player();
		}
		
		_propsBack.sort(sortByScrollX);
		_propsFore.sort(sortByScrollX);
	}
	
	private inline function sortByScrollX(order:Int, s1:FlxSprite, s2:FlxSprite)
	{
		return FlxSort.byValues(order, s1.scrollFactor.x, s2.scrollFactor.x);
	}
	
	/** --------------------------------------------------------------------------------------------------------------------------------
	 *  Adds 750 unit wide borders to the map of the color defined, to prevent things like parallax sprites from scrolling out of bounds
	 *  -------------------------------------------------------------------------------------------------------------------------------- */
	private function addMapBorders(BackgroundColor:FlxColor):Void 
	{
		var BORDERSIZE:Int = 750;
		var BorderNorth:FlxSprite = new FlxSprite(_tilemapMain.x - BORDERSIZE, _tilemapMain.y - BORDERSIZE);
		BorderNorth.makeGraphic(Std.int(BORDERSIZE * 2 + _tilemapMain.width), BORDERSIZE, BackgroundColor);
		add(BorderNorth);
		var BorderSouth:FlxSprite = new FlxSprite(_tilemapMain.x - BORDERSIZE, _tilemapMain.y + _tilemapMain.height);
		BorderSouth.makeGraphic(Std.int(BORDERSIZE * 2 + _tilemapMain.width), BORDERSIZE, BackgroundColor);
		add(BorderSouth);
		var BorderEast:FlxSprite = new FlxSprite(_tilemapMain.x + _tilemapMain.width, _tilemapMain.y);
		BorderEast.makeGraphic(BORDERSIZE, Std.int(_tilemapMain.height), BackgroundColor);
		add(BorderEast);
		var BorderWest:FlxSprite = new FlxSprite(_tilemapMain.x - BORDERSIZE, _tilemapMain.y);
		BorderWest.makeGraphic(BORDERSIZE, Std.int(_tilemapMain.height), BackgroundColor);
		add(BorderWest);
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
			
			Reg.levelTimer += FlxG.elapsed;
		}
		
		if ( Reg.gameTimerStarted )
		{
			Reg.gameTimer += FlxG.elapsed;
		}
		
		gameHUD.levelTimerText.text = "Level time: " + Std.int(Reg.levelTimer * 1000) / 1000;
		gameHUD.gameTimerText.text = "Total time: " + Std.int(Reg.gameTimer * 10) / 10;
		
		if ( player.living )
		{
			if ( gameHUD.deadText.alive )
				gameHUD.deadText.kill();
				
			if ( FlxG.collide(_tilemapMain, player) )
			{
				_tilemapMain.updateBuffers();
			}
			
			if ( FlxG.collide(platforms, player) )
				player.onPlatform = true;
			
			//Don't let player leave the map
			player.ConstrainToMap( _tilemapMain.x, _tilemapMain.y, _tiledMap.fullWidth, _tiledMap.fullHeight );
			
			// Handle player/checkpoint overlap @TODO: is it safe to kill the checkpoint in player..?
			FlxG.overlap( player, _checkpoints, player.touchCheckpoint );
			
			if ( FlxG.overlap( player, _goal ) )
				player.goalMet();

			if ( player.levelBeat == false )
			{
				if ( _tilemapOoze.overlapsWithCallback( player.innerHitbox, function(P:FlxObject, T:FlxObject) { return FlxG.overlap( P, T ); }, true ) )
				{
					player.died(CauseOfDeath.MELTING);
				}
				
				if ( FlxG.overlap( player, _signs, function(P:FlxObject, S:Sign) { gameHUD.ToggleSign(true, S.signText); return FlxG.overlap( P, S ); } ) )
				{
					// (Logic is handled in the overlap function)
				}
				else if ( gameHUD.signText.alive )
				{
					gameHUD.ToggleSign(false);
				}
				
				if ( gameHUD.levelFinishedText.alive )
				{
					gameHUD.levelFinishedText.kill();
				}
			}
			else
			{
				if ( Reg.levelnum < Reg.levelnames.length - 1 )
				{
					gameHUD.levelFinishedText.text = "Goal! Press JUMP to go to the next level!";
				}
				else
				{
					var s = Std.string( Reg.gameTimer );
					var i = s.indexOf( '.' );
					s = s.substr( 0, i + 4 );
					
					gameHUD.levelFinishedText.text = "You beat all the levels! Nice work!\nTotal time: " + s + "\nHit JUMP to play through it again.";
					Reg.gameTimerStarted = false;
				}
				
				if ( gameHUD.levelFinishedText.alive == false )
				{
					gameHUD.levelFinishedText.revive();
				}
				
				// Current level finished, change to next level
				if ( FlxG.keys.justPressed.ENTER || player.m_bJumpPressedThisFrame )
				{
					loadNextLevel();
				}
			}
		}
		else
		{
			gameHUD.deadText.revive();
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
		//@TODO: follow the advice and set stuff null here.
		super.destroy();
	}
}
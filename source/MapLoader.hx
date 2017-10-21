package;

import haxe.xml.Fast;
import openfl.Assets;

import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.math.FlxPoint;
import flixel.group.FlxGroup;
import flixel.util.FlxSort;
import flixel.util.FlxColor;

import flixel.tile.FlxTilemap;
import flixel.tile.FlxBaseTilemap;
import flixel.graphics.frames.FlxTileFrames;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.editors.tiled.TiledMap;
import flixel.addons.editors.tiled.TiledLayer;
import flixel.addons.editors.tiled.TiledObjectLayer;
import flixel.addons.editors.tiled.TiledTileSet;
import flixel.addons.editors.tiled.TiledTileLayer;

import entities.Player;
import entities.Checkpoint;
import entities.Goal;
import entities.Prop;
import entities.Rocket;
import entities.Sign;
import entities.Coin;
import entities.Platform;

using StringTools;

class MapLoader extends FlxBasic
{
	public var mapGroup:FlxGroup = new FlxGroup();
	
    private var _tiledMap:TiledMap;
	private var _tilemapMain:RJ_TilemapExt;
	private var _tilemapOoze:FlxTilemap;
	private var _tilemapBackground:FlxTilemap;
	private var _tilemapDetail:FlxTilemap;

    public var platforms:FlxGroup = new FlxGroup();

   	private var _objectImageGIDs = new List<{ObjectGID:Int, ObjectFilename:String}>();
	private var _checkpoints:FlxTypedGroup<Checkpoint> = new FlxTypedGroup<Checkpoint>();
	private var _signs:FlxTypedGroup<Sign> = new FlxTypedGroup<Sign>();
	private var _coins:FlxTypedGroup<Coin> = new FlxTypedGroup<Coin>();
	private var _propsBack:FlxTypedGroup<Prop> = new FlxTypedGroup<Prop>();
	private var _propsMid:FlxTypedGroup<Prop> = new FlxTypedGroup<Prop>();
	private var _propsFore:FlxTypedGroup<Prop> = new FlxTypedGroup<Prop>();
	private var _goal:Goal;


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
	public function setupLevel():Void
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
		FlxG.state.add(backdrop);	
		
		mapGroup.add( _tilemapBackground );
		mapGroup.add( _tilemapDetail );
		mapGroup.add( _tilemapOoze );
		mapGroup.add( _tilemapMain );		
		
		FlxG.worldBounds.set(0, 0, _tiledMap.fullWidth, _tiledMap.fullHeight);

        loadEntities();
	}

	
	/** -------------------------------------------------------------------------------------
	 *  Creates and loads requisite data from the tilemap for all entities present in the map
	 *  ------------------------------------------------------------------------------------- */
	private function loadEntities():Void
	{
        var playState:PlayState = cast FlxG.state;

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
						playState.player = new Player(x, y + o.height - Player.HITBOX_HEIGHT); // Create the player at the bottom of the spawn point
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
						
						// Fix up hitboxes for props that are cardinally aligned (can't support non-cardinal rotations)
						if (prop.angle < 0)
						{
							// For some reason, Tiled rotations are always negative	// @TODO: revisit this garbage??						
							if (prop.angle % -270 == 0)
							{
								var tempWidth = prop.width;
								prop.width = prop.height;
								prop.height = tempWidth;
								prop.offset.set(0, prop.height * 2);
								prop.y += prop.height * 2;
							}
							else if (prop.angle % -180 == 0)
							{
								prop.offset.set( -prop.width, prop.height);
								prop.x -= prop.width;
								prop.y += prop.height;
							}
							else if (prop.angle % -90 == 0)
							{
								var tempWidth = prop.width;
								prop.width = prop.height;
								prop.height = tempWidth;
								prop.offset.set(-prop.width, prop.height);
								prop.y += prop.height;
								prop.x -= prop.width;
							}
						}
						
						var forceForeground:Bool = false;

						// See if the prop has a "scrollx" property (for scrollFactor.x, i.e. parallax) and set it
						if ( o.xmlData.hasNode.properties )
						{
							for ( Property in o.xmlData.node.properties.nodes.property )
							{
								if ( Property.att.name == "scrollx" )
									prop.scrollFactor.x = Std.parseFloat(Property.att.value);
								else if ( Property.att.name == "forcefore" )
									forceForeground = true;
							}
						}
						
						// Figure out which group to add the prop to based on scrollfactor (for z-ordering)
						if(prop.scrollFactor.x > 1.0 || forceForeground)
						{
							_propsFore.add(prop);
						}
						else if ( prop.scrollFactor.x < 1.0 )
						{
							_propsBack.add(prop);
							prop.color = prop.color.getDarkened( Math.abs(prop.scrollFactor.x - 1) );
							//prop.scrollFactor.y = Reg.RemapValClamped(prop.scrollFactor.x, 0.0, 1.0, 0.75, 1.0); // TODO: not sure if I want this (slight vertical parallax based on horiz. parallax)
						}
						else if ( prop.scrollFactor.x == 1.0 )
						{
							_propsMid.add(prop);
						}
						
						// Offset the prop, if it has scrollfactor, so that it lines up with the player being at it's position in Tiled (normally it's position is just modified naively)
						if ( prop.scrollFactor.x != 1.0 )
						{
							var halfWidth:Float = FlxG.width * 0.5;
							prop.x -= prop.getMidpoint().x - (prop.getMidpoint().x * prop.scrollFactor.x); // Prop position offset
							prop.x += halfWidth - (halfWidth * prop.scrollFactor.x); // Half screen width offset
						}
						
					//end switch statement
				}	
			}
		}

		if ( playState.player == null )
		{
			trace("Warning: Player start not found! Spawning player at 0, 0");
			playState.player = new Player();
		}
		
		_propsBack.sort(sortByScrollX);
		_propsFore.sort(sortByScrollX);
	}
	
	private inline function sortByScrollX(order:Int, s1:FlxSprite, s2:FlxSprite)
	{
		return FlxSort.byValues(order, s1.scrollFactor.x, s2.scrollFactor.x);
	}

    public function addBackgroundObjects(state:FlxState):Void
    {
		state.add( _propsBack );
		
		state.add(_tilemapBackground);
		state.add(_tilemapDetail);
		
		state.add(platforms);
	
		state.add( _propsMid );
		
		state.add( _goal );
		state.add( _checkpoints );
		state.add( _signs );
		state.add( _coins );
    }

    public function addForegroundObjects(state:FlxState):Void
    {
		state.add(_tilemapOoze);
		state.add(_tilemapMain);
		
		state.add( _propsFore );
    }

    /** Get tilemap size in pixels */
    public function getMapSize():FlxPoint
    {
        return FlxPoint.get(_tilemapMain.width, _tilemapMain.height);
    }

    /**
     *  Handles all tilemap and map object related overlaps and collisions against the player entity
     *  @param   player 
     */
    public function handlePlayerOverlaps(player:Player):Void
    {
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

            if ( FlxG.overlap( player, _signs, function(P:FlxObject, S:Sign) { Reg.HUD.ToggleSign(true, S.signText); return FlxG.overlap( P, S ); } ) )
            {
                // (Logic is handled in the overlap function)
            }
            else if ( Reg.HUD.signText.alive )
            {
                Reg.HUD.ToggleSign(false);
            }
            
            if ( Reg.HUD.levelFinishedText.alive )
            {
                Reg.HUD.levelFinishedText.kill();
            }
        }
        else
        {
            if ( Reg.levelnum < Reg.levelnames.length - 1 )
            {
                Reg.HUD.levelFinishedText.text = "Goal! Press JUMP to go to the next level!";
            }
            else
            {
                var s = Std.string( Reg.gameTimer );
                var i = s.indexOf( '.' );
                s = s.substr( 0, i + 4 );
                
                Reg.HUD.levelFinishedText.text = "You beat all the levels! Nice work!\nTotal time: " + s + "\nHit JUMP to play through it again.";
                Reg.gameTimerStarted = false;
            }
            
            if ( Reg.HUD.levelFinishedText.alive == false )
            {
                Reg.HUD.levelFinishedText.revive();
            }
        }
    }
}
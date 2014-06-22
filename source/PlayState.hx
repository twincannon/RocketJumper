package;

import entities.Goal;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.tile.FlxTilemap;
import flixel.ui.FlxButton;
import flixel.util.FlxMath;
import flixel.FlxObject;
import flixel.util.FlxPoint;
import haxe.xml.Fast;
import openfl.Assets;
import entities.Player;
import flixel.util.FlxRect;
import flixel.group.FlxTypedGroup;
import flixel.addons.editors.ogmo.FlxOgmoLoader;
import entities.Checkpoint;
import flixel.util.FlxColor;
import flixel.util.FlxAngle;

/**
 * A FlxState which can be used for the actual gameplay.
 */
class PlayState extends FlxState
{
	public var backgroundTiles:FlxTypedGroup<FlxSprite>; //make background a 40x40 shit with like fencing, doors, windows, etc
	private var checkpoints:FlxTypedGroup<Checkpoint>;
	private var goal:Goal;
	private var camera:FlxCamera;
	private var m_tileMap:FlxOgmoLoader; //@TODO rename this stupid var.. and the "map" in reg.. currentlevel or something?????? or actually i bet THIS needs to be in reg..fuck, we'll see.
	private var map:FlxTilemap;
	private var ooze:FlxTilemap;
	private var mapbg:FlxTilemap;
	private var detailmap:FlxTilemap;
	private var m_sprCrosshair:FlxSprite;
	private var deadText:FlxText;
	private var timerText:FlxText;
	private var levelNameText:FlxText;
	private var levelFinishedText:FlxText;
	
	/**
	 * Function that is called up when to state is created to set it up. 
	 */
	override public function create():Void
	{
		super.create();
		
		if ( !Reg.levelsloaded )
		{
			//Assets.getText
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
		

#if debug
		//FlxG.debugger.drawDebug = true;
#end
		m_tileMap = new FlxOgmoLoader("assets/data/"+Reg.levelnames[Reg.levelnum]);
		mapbg = m_tileMap.loadTilemap("assets/images/tilesbg.png", 20, 20, "tilesbg");
		map = m_tileMap.loadTilemap("assets/images/tiles.png", 20, 20, "tiles"); //for some reason if using assetpath.tiles__png here, c++ doesnt compile??
		detailmap = m_tileMap.loadTilemap("assets/images/tilesdetail.png", 20, 20, "tilesdetail");
		ooze = m_tileMap.loadTilemap("assets/images/tiles_ooze.png", 20, 20, "ooze");
		
		mapbg.allowCollisions = FlxObject.NONE;
		detailmap.allowCollisions = FlxObject.NONE;
		
		checkpoints = new FlxTypedGroup<Checkpoint>();
		
		backgroundTiles = new FlxTypedGroup<FlxSprite>();
		var bgW = 303;
		var bgH = 256;
		
		//@TODO make 4 of these in a classic scrolling bg style instead of making way too many to cover the map
		//also maybe make a different background type for fun
		for (i in -1...4)
		{
			for (j in -1...4)
			{
				var bgtile = new FlxSprite( i * bgW, j * bgH, "assets/images/background.png" );
				bgtile.scrollFactor.x = bgtile.scrollFactor.y = 0.5;
				bgtile.width = 0;
				bgtile.height = 0;
				bgtile.allowCollisions = FlxObject.NONE;
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

		Reg.player = new Player(); //should i make this in placeentities? but then i'd need to check for player existing everywhere
		goal = new Goal();
		m_tileMap.loadEntities(placeEntities, "entities");
		
		add(goal);
		add(checkpoints);
		add(Reg.player);
		Reg.player.addFireEffect(); //add fireeffect after player for proper z-ordering
		
		deadText = new FlxText( FlxG.width / 2 - 75, 50, 150, "Dead! Press [R] or (X) to respawn.");
		deadText.color = FlxColor.WHITE;
		deadText.scrollFactor.set( 0, 0 );
		deadText.alignment = "center";
		add(deadText);
		deadText.kill();
		
		timerText = new FlxText( 10, 10, 100, "Time: "+Reg.player.levelTimer );
		timerText.color = FlxColor.WHITE;
		timerText.scrollFactor.set( 0, 0 );
		add(timerText);
		
		var levelFinishedTextWidth = 250;
		levelFinishedText = new FlxText( FlxG.width / 2 - levelFinishedTextWidth / 2, 50, levelFinishedTextWidth, "Level finished text" );
		levelFinishedText.scrollFactor.set( 0, 0 );
		levelFinishedText.alignment = "center";
		add(levelFinishedText);
		levelFinishedText.kill();
		
		Reg.leveltitle = Reg.leveltitles[Reg.levelnum];
		var levelNameTextWidth = 200;
		levelNameText = new FlxText(FlxG.width - levelNameTextWidth - 10, 10, levelNameTextWidth, Reg.leveltitle);
		levelNameText.scrollFactor.set(0, 0);
		levelNameText.alignment = "right";
		add(levelNameText);
		
		//custom mouse cursor
		m_sprCrosshair = new FlxSprite( 0, 0, AssetPaths.cursor__png );
		m_sprCrosshair.scrollFactor.set(0, 0);
		FlxG.mouse.visible = false;
		add( m_sprCrosshair );
		
		//snap camera to world, follow the player, and make entire world collidable
		FlxG.camera.follow(Reg.player, FlxCamera.STYLE_LOCKON, 0.0/*0.5*/);
	//	FlxG.camera.deadzone = FlxRect.get( FlxG.width / 2, FlxG.height / 2 - 40, 0, 50 ); //causes weird issues with horizontal pixel lines?? see http://i.imgur.com/FHGaahO.gif
		FlxG.camera.setBounds(0, 0, map.width, map.height);		
		FlxG.worldBounds.set(0, 0, m_tileMap.width, m_tileMap.height);
	}
	
	private function placeEntities( entityName:String, entityData:Xml ):Void
	{
		//@TODO  CREATE these objects here so i can do stuff like
		//pass x/y and have it set via create() instead of doing this nonsense
		
		var x:Int = Std.parseInt(entityData.get("x"));
		var y:Int = Std.parseInt(entityData.get("y"));
		if ( entityName == "player" )
		{
			Reg.player.x = x;
			Reg.player.y = y;
			Reg.player.originalSpawnPoint = FlxPoint.get( x, y );
			Reg.player.spawnPoint = FlxPoint.get( x, y );
		}
		else if ( entityName == "checkpoint" )
		{
			var w:Int = Std.parseInt(entityData.get("width"));
			var h:Int = Std.parseInt(entityData.get("height"));
			var num:Int = Std.parseInt(entityData.get("num"));
			var chkpt = new Checkpoint( x, y, w, h, num );
			checkpoints.add( chkpt );
		}
		else if ( entityName == "goal" )
		{
			goal.x = x;
			goal.y = y;
			goal.setSize( 20, 40 ); //@TODO parameterize these somewhere
		}
	}
	/**
	 * Function that is called when this state is destroyed - you might want to 
	 * consider setting all objects this state uses to null to help garbage collection.
	 */
	override public function destroy():Void
	{
		super.destroy();
	}

	/**
	 * Function that is called once every frame.
	 */
	override public function update():Void
	{
#if !flash
		if ( FlxG.keys.justPressed.ESCAPE )
			Sys.exit(0);
#end

		if ( Reg.player.usingMouse )
			m_sprCrosshair.setPosition( Math.ceil(FlxG.mouse.screenX - m_sprCrosshair.width / 2), Math.ceil(FlxG.mouse.screenY - m_sprCrosshair.height / 2) );
		else
			m_sprCrosshair.setPosition( Reg.player.getScreenXY().x + Reg.player.crosshairLocation.x ,//- m_sprCrosshair.width / 2,
										Reg.player.getScreenXY().y + Reg.player.crosshairLocation.y );// - m_sprCrosshair.height / 2);
										
		
		// Update crosshair line to player
		var xhairScreenCenter:FlxPoint = FlxPoint.get( m_sprCrosshair.getScreenXY().x + m_sprCrosshair.width / 2, m_sprCrosshair.getScreenXY().y + m_sprCrosshair.height / 2 );
		var playerShootScreenCenter:FlxPoint = FlxPoint.get( Reg.player.getScreenXY().x + Reg.player.width / 2 , Reg.player.getScreenXY().y + Reg.player.height / 2 - Reg.PLAYER_SHOOT_Y_OFFSET + 2 );
		Reg.player.crosshairLine.setPosition( xhairScreenCenter.x, xhairScreenCenter.y );
		Reg.player.crosshairLine.origin.set( 0, 0 );
		
		var angle = FlxAngle.getAngle( playerShootScreenCenter, xhairScreenCenter );
		Reg.player.crosshairLine.angle = angle;
		
		var distance:Float = xhairScreenCenter.distanceTo( playerShootScreenCenter );
		
		Reg.player.crosshairLine.scale.y = Reg.RemapValClamped( distance, 150, 20, 1.0, 0.0 );
		Reg.player.crosshairLine.alpha = Reg.RemapValClamped( distance, 100, 20, 1.0, 0.0 );
		
		super.update();
		
		if ( Reg.gameTimerStarted )
			Reg.gameTimer += FlxG.elapsed;
		
		timerText.text = "Time: " + Std.int(Reg.player.levelTimer*1000) / 1000;
		
		if ( Reg.player.living )
		{
			if ( deadText.alive )
				deadText.kill();
				
			FlxG.collide(map, Reg.player);
			
			//Don't let player leave the map (horizontally)
			if ( Reg.player.x < map.x )
				Reg.player.x = map.x;
			else if ( Reg.player.x + Reg.player.width > map.width )
				Reg.player.x = map.width - Reg.player.width;
			
			if ( Reg.player.y > map.height || Reg.player.y < map.y )
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
			
			if ( !Reg.player.levelBeat && Reg.player.living )
			{
				if ( ooze.overlapsWithCallback( Reg.player,
												function(P:FlxObject, T:FlxObject) { return  FlxG.overlap( P, T ); },
												true ) ) //the bool here makes this return the specific FlxTile to the function
				{
					Reg.player.melting = true;
				}
			}
			
			if ( Reg.player.levelBeat )
			{
				if ( Reg.levelnum < Reg.levelnames.length - 1 )
				{
					levelFinishedText.text = "Goal! Hit [ENTER] or (Y) to go to next level!";
				}
				else
				{
					levelFinishedText.text = "You beat all the levels! Nice work!\nTotal time: " + Reg.gameTimer + "\nHit [ENTER] or (Y) to play through it again.";
					Reg.gameTimerStarted = false;
				}
				levelFinishedText.revive();
			}
			else
				levelFinishedText.kill();
		}
		else
		{
			deadText.revive();
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
}
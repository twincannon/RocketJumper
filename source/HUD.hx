package ;
import flixel.group.FlxGroup;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.FlxG;
import flixel.tile.FlxTilemap;
import flixel.util.FlxColor;
import flixel.FlxObject;
import flixel.FlxCamera;

/**
 * ...
 * @author 
 */
class HUD extends FlxGroup
{
	public var deadText:FlxText;
	public var timerText:FlxText;
	public var levelNameText:FlxText;
	public var levelFinishedText:FlxText;
	public var signText:FlxText;
	public var signTextBox:FlxSprite;
	public var centerPoint:FlxSprite;
	
	//public var minimap:FlxTilemap;
	//public var minimapbg:FlxTilemap;
	
	public var camera:FlxCamera;
	
	private var x:Float = 10000;
	private var y:Float = 0;
	
	private var signTextWidth = 600;
	private var signTextY = 40;
	private var signTextBuffer = 30;
	private var levelFinishedTextWidth = 700;
	private var levelFinishedTextY = 150;
	private var levelNameTextWidth = 400;
	private var deadTextWidth = 700;
	private var deadTextY = 150;
	private var timerTextWidth = 300;
	private var cornerTextBuffer = 20;
	
	private var tl:FlxSprite;
	private var tr:FlxSprite;
	private var bl:FlxSprite;
	private var br:FlxSprite;
	private var RENDER_DEBUG_STUFF:Bool = false;

	public function new( W:Int, H:Int ) 
	{
		super();
		
		centerPoint = new FlxSprite(x + W/2 - 2, y + H/2 - 2);
		centerPoint.makeGraphic(4, 4, FlxColor.PINK);
		if( RENDER_DEBUG_STUFF )
			add(centerPoint);
		
	//	minimap = new FlxTilemap(); //loaded in PlayState:setupLevel()
	//	minimapbg = new FlxTilemap();
		
		camera = new FlxCamera( 0, 0, W, H, 1 );
		camera.follow( centerPoint );
		camera.bgColor = RENDER_DEBUG_STUFF ? 0x66993333 : 0x00000000;
		FlxG.cameras.add( camera );
		
		if ( RENDER_DEBUG_STUFF )
		{
			tl = new FlxSprite( x, y );
			tl.makeGraphic(10, 10, FlxColor.PINK);
			add(tl);
			
			tr = new FlxSprite( x+W-10, y );
			tr.makeGraphic(10, 10, FlxColor.PINK);
			add(tr);
			
			bl = new FlxSprite( x, y+H-10 );
			bl.makeGraphic(10, 10, FlxColor.PINK);
			add(bl);
			
			br = new FlxSprite( x+W-10, y+H-10 );
			br.makeGraphic(10, 10, FlxColor.PINK);
			add(br);
		}
		

		signTextBox = new FlxSprite( 0, 0, AssetPaths.signtextbox__png );
		signTextBox.allowCollisions = FlxObject.NONE;
		add(signTextBox);
		signTextBox.kill();
		
		deadText = new FlxText( 0, 0, deadTextWidth, "Dead! Press [R] or (X) to respawn.");
		setBorder( deadText, 32, "center", FlxColor.PINK );
		add(deadText);
		deadText.kill();
		
		timerText = new FlxText( 0, 0, timerTextWidth, "Level timer" );
		setBorder( timerText, 24, "left" );
		add(timerText);
		
		levelFinishedText = new FlxText( 0, 0, levelFinishedTextWidth, "Level finished text" );
		setBorder( levelFinishedText, 24, "center" );
		add(levelFinishedText);
		levelFinishedText.kill();
		
		Reg.leveltitle = Reg.leveltitles[Reg.levelnum];
		levelNameText = new FlxText( 0, 0, levelNameTextWidth, Reg.leveltitle);
		setBorder( levelNameText, 16, "right" );
		add(levelNameText);
		
		signText = new FlxText( 0, 0, signTextWidth - signTextBuffer*2, "I'm a sign!" );
		setBorder( signText, 16, "center" );
		add(signText);
		signText.kill();
		
		//minimapbg.setSize(180, 100); //instead of setting size/position, we need to just center it / offset it based on its w/h
	//	minimapbg.setPosition(x, y);
	//	minimapbg.allowCollisions = FlxObject.NONE;
	//	add(minimapbg);
		//so this is laggy as fuck. what we need to do is use this to make a bitmap
		
	//	minimap.setPosition(x, y);
	//	minimap.allowCollisions = FlxObject.NONE;
	//	add(minimap);
		
		updateSizes(x, y, W, H);
	}

	private function setBorder( Text:FlxText, Size:Float, Align:String, Color:Int = FlxColor.WHITE ):Void
	{
		Text.borderSize = 2;
		Text.borderStyle = FlxText.BORDER_OUTLINE_FAST;
		Text.borderColor = 0xFF2266AA;
		Text.size = Size;
		Text.alignment = Align;
		Text.color = Color;
	}
	
	public function updateSizes( X:Float, Y: Float, W:Int, H:Int ):Void
	{
		camera.setSize( W, H );

		centerPoint.setPosition(x + W / 2, y + H / 2);
		camera.follow(centerPoint);
		
		x += X;
		y += Y;
		
	//	minimap.setPosition(x + W / 2, y + H / 2);
	//	minimapbg.setPosition(x + W / 2, y + H / 2);
		/*
		if ( minimapbg.cachedGraphics != null )
		{
		var fuck:FlxSprite = new FlxSprite( x, y, minimapbg.cachedGraphics.bitmap );
		add(fuck);
		}
		*/
		
		if ( RENDER_DEBUG_STUFF )
		{
			tl.setPosition( x, y );
			tr.setPosition( x+W-10, y );
			bl.setPosition( x, y+H-10 );
			br.setPosition( x + W - 10, y + H - 10 );
		}
		
		signTextBox.setPosition( x + W / 2 - signTextWidth / 2, y + signTextY );
		deadText.setPosition( x + W / 2 - deadTextWidth/2, y + deadTextY );
		timerText.setPosition( x + cornerTextBuffer, y + cornerTextBuffer );
		levelFinishedText.setPosition( x + W / 2 - levelFinishedTextWidth / 2, y + levelFinishedTextY );
		levelNameText.setPosition( x + W - levelNameTextWidth - cornerTextBuffer, y + cornerTextBuffer );
		signText.setPosition( x + W / 2 - signTextWidth / 2 + signTextBuffer, y + signTextY + signTextBuffer );
	}
}
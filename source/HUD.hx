package ;
import flixel.group.FlxGroup;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.FlxG;
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
		deadText.color = FlxColor.WHITE;
		deadText.alignment = "center";
		deadText.size = 32;
		setBorder( deadText );
		add(deadText);
		deadText.kill();
		
		timerText = new FlxText( 0, 0, timerTextWidth, "Time: "+Reg.player.levelTimer );
		timerText.color = FlxColor.WHITE;
		timerText.size = 24;
		setBorder( timerText );
		add(timerText);
		
		levelFinishedText = new FlxText( 0, 0, levelFinishedTextWidth, "Level finished text" );
		levelFinishedText.alignment = "center";
		levelFinishedText.size = 24;
		setBorder( levelFinishedText );
		add(levelFinishedText);
		levelFinishedText.kill();
		
		Reg.leveltitle = Reg.leveltitles[Reg.levelnum];
		levelNameText = new FlxText( 0, 0, levelNameTextWidth, Reg.leveltitle);
		levelNameText.alignment = "right";
		levelNameText.size = 16;
		setBorder( levelNameText );
		add(levelNameText);
		
		signText = new FlxText( 0, 0, signTextWidth - signTextBuffer*2, "I'm a sign!" );
		signText.alignment = "center";
		signText.size = 16;
		setBorder( signText );
		add(signText);
		signText.kill();
		
		updateSizes(x, y, W, H);
	}
	
	private function setBorder( Text:FlxText ):Void
	{
		Text.borderSize = 2;
		Text.borderStyle = FlxText.BORDER_OUTLINE_FAST;
		Text.borderColor = 0xFF2266AA;
	}
	
	public function updateSizes( X:Float, Y: Float, W:Int, H:Int ):Void
	{
		camera.setSize( W, H );

		centerPoint.setPosition(x + W / 2, y + H / 2);
		camera.follow(centerPoint);
		
		x += X;
		y += Y;
		
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
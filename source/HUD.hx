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
	public var levelTimerText:FlxText;
	public var gameTimerText:FlxText;
	public var levelNameText:FlxText;
	public var levelFinishedText:FlxText;
	public var signText:FlxText;
	public var signTextBox:FlxSprite;
	public var centerPoint:FlxSprite;
	
	/*public var minimap:FlxTilemap;
	public var minimapbg:FlxTilemap;*/
	
	public var hudcamera:FlxCamera;
	
	private var x:Float = 10000; // HUD assets are off in space so they're not in the game world (they just render via a camera)
	private var y:Float = 0;
	
	private var signTextWidth = 600;
	private var signTextY = 40;
	private var signTextBuffer = 30;
	private var levelFinishedTextWidth = 700;
	private var levelFinishedTextY = 150;
	private var levelNameTextWidth = 400;
	private var deadTextWidth = 700;
	private var deadTextY = 150;
	private var timerTextWidth = 350;
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
		
	/*	minimap = new FlxTilemap(); //loaded in PlayState:setupLevel()
		minimapbg = new FlxTilemap();*/
		
		hudcamera = new FlxCamera( 0, 0, W, H, 1 );
		hudcamera.follow( centerPoint );
		hudcamera.bgColor = RENDER_DEBUG_STUFF ? 0x66993333 : 0x00000000;
		FlxG.cameras.add( hudcamera );
		
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
		
		levelTimerText = new FlxText( 0, 0, timerTextWidth, "Level timer" );
		setBorder( levelTimerText, 24, "left" );
		add(levelTimerText);
		
		gameTimerText = new FlxText( 0, 0, timerTextWidth, "Game timer" );
		setBorder( gameTimerText, 24, "left" );
		add(gameTimerText);
		
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
		
	/*	minimapbg.setPosition(x, y);
		minimapbg.allowCollisions = FlxObject.NONE;
		add(minimapbg);
		//so this is laggy as fuck. what we need to do is use this to make a bitmap
		
		minimap.setPosition(x, y);
		minimap.allowCollisions = FlxObject.NONE;
		add(minimap);*/
		
		
		updateSizes(0, 0, W, H);
	}

	private function setBorder( Text:FlxText, Size:Int, Align:String, Color:Int = FlxColor.WHITE ):Void
	{
		//@TODO: look into/use FlxTextFormat instead
		Text.borderSize = 2;
		Text.borderStyle = FlxTextBorderStyle.SHADOW;
		Text.borderColor = 0xFF2266AA;
		Text.size = Size;
		Text.alignment = Align;
		Text.color = Color;
	}
	
	public function updateSizes( X:Float, Y: Float, W:Int, H:Int ):Void
	{
		centerPoint.setPosition(x + W / 2, y + H / 2);
		hudcamera.follow(centerPoint);
		
		x += X;
		y += Y;
		
	/*	minimap.setPosition(x + W / 2, y + H / 2);
		minimapbg.setPosition(x + W / 2, y + H / 2);*/
		
		/*
		if ( minimapbg.cachedGraphics != null )
		{
		var test:FlxSprite = new FlxSprite( x, y, minimapbg.cachedGraphics.bitmap );
		add(test);
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
		deadText.setPosition( x + W / 2 - deadTextWidth / 2, y + deadTextY );
		
		levelTimerText.setPosition( x + cornerTextBuffer, y + cornerTextBuffer );
		gameTimerText.setPosition( x + cornerTextBuffer, y + cornerTextBuffer + 30 );
		
		levelFinishedText.setPosition( x + W / 2 - levelFinishedTextWidth / 2, y + levelFinishedTextY );
		levelNameText.setPosition( x + W - levelNameTextWidth - cornerTextBuffer, y + cornerTextBuffer );
		signText.setPosition( x + W / 2 - signTextWidth / 2 + signTextBuffer, y + signTextY + signTextBuffer );
	}
	
	public function ToggleSign( Active:Bool, Text:String = "" ):Void
	{
		if ( Active )
		{
			if ( !signTextBox.alive )
			{
				signText.text = Text;
				
				var testFormat:FlxTextFormat = new FlxTextFormat(FlxColor.WHITE, false, false, FlxColor.ORANGE);
				signText.applyMarkup(Text, [new FlxTextFormatMarkerPair(testFormat, "$")]);
				
				signTextBox.revive();
				signText.revive();
				
				//@TODO: play a sound here, or make the text scroll in character-by-character with sfx
			}
		}
		else
		{
			if ( signTextBox.alive )
			{
				signTextBox.kill();
				signText.kill();
			}
		}
	}
}
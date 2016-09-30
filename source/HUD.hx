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
	public var inputModeText:FlxText;

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
		
		hudcamera = new FlxCamera( 0, 0, W, H, 1 );
		hudcamera.follow( centerPoint );
		hudcamera.bgColor = RENDER_DEBUG_STUFF ? 0x66993322 : 0x00000000;
		FlxG.cameras.add( hudcamera );

		// Center point used as a focal point for the camera, we don't actually render it
		centerPoint = new FlxSprite(x + W/2 - 2, y + H/2 - 2);
		
		if ( RENDER_DEBUG_STUFF )
		{
			centerPoint.makeGraphic(4, 4, FlxColor.PINK);
			centerPoint.camera = hudcamera;
			add(centerPoint);
			
			tl = new FlxSprite( x, y );
			tl.makeGraphic(10, 10, FlxColor.PINK);
			tl.camera = hudcamera;
			add(tl);
			
			tr = new FlxSprite( x+W-10, y );
			tr.makeGraphic(10, 10, FlxColor.PINK);
			tr.camera = hudcamera;
			add(tr);
			
			bl = new FlxSprite( x, y+H-10 );
			bl.makeGraphic(10, 10, FlxColor.PINK);
			bl.camera = hudcamera;
			add(bl);
			
			br = new FlxSprite( x+W-10, y+H-10 );
			br.makeGraphic(10, 10, FlxColor.PINK);
			br.camera = hudcamera;
			add(br);
		}
		
		signTextBox = new FlxSprite( 0, 0, AssetPaths.signtextbox__png );
		signTextBox.camera = hudcamera;
		signTextBox.allowCollisions = FlxObject.NONE;
		add(signTextBox);
		signTextBox.kill();
		
		deadText = new FlxText( 0, 0, deadTextWidth, "Dead! Press [R] or (X) to respawn.");
		deadText.camera = hudcamera;
		setBorder( deadText, 32, "center", FlxColor.PINK );
		add(deadText);
		deadText.kill();
		
		levelTimerText = new FlxText( 0, 0, timerTextWidth, "Level timer" );
		levelTimerText.camera = hudcamera;
		setBorder( levelTimerText, 24, "left" );
		add(levelTimerText);
		
		gameTimerText = new FlxText( 0, 0, timerTextWidth, "Game timer" );
		gameTimerText.camera = hudcamera;
		setBorder( gameTimerText, 24, "left" );
		add(gameTimerText);
		
		levelFinishedText = new FlxText( 0, 0, levelFinishedTextWidth, "Level finished text" );
		levelFinishedText.camera = hudcamera;
		setBorder( levelFinishedText, 24, "center" );
		add(levelFinishedText);
		levelFinishedText.kill();
		
		Reg.leveltitle = Reg.leveltitles[Reg.levelnum];
		levelNameText = new FlxText( 0, 0, levelNameTextWidth, Reg.leveltitle);
		levelNameText.camera = hudcamera;
		setBorder( levelNameText, 16, "right" );
		add(levelNameText);
		
		inputModeText = new FlxText( 0, 0, levelNameTextWidth, "Input Mode");
		inputModeText.camera = hudcamera;
		setBorder( inputModeText, 16, "right" );
		add(inputModeText);
		
		signText = new FlxText( 0, 0, signTextWidth - signTextBuffer*2, "I'm a sign!" );
		signText.camera = hudcamera;
		setBorder( signText, 16, "center" );
		add(signText);
		signText.kill();
		
		updateSizes(0, 0, W, H);
	}
	
	public function setInputModeText( Text:String ):Void
	{
		inputModeText.text = Text;
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
		
		inputModeText.setPosition( x + W - levelNameTextWidth - cornerTextBuffer, y + cornerTextBuffer * 2 );
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
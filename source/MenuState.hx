package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import openfl.Assets;

/**
 * A FlxState which can be used for the game's menu.
 */
class MenuState extends FlxState
{
	private var logo:FlxSprite;
	private var logotimer:Float = 0;
	
	/**
	 * Function that is called up when to state is created to set it up. 
	 */
	override public function create():Void
	{
		super.create();
		logo = new FlxSprite(0, 0);
		logo.loadGraphic(Assets.getBitmapData("assets/images/phglogo.png"), false);
		add(logo);
		logo.x = FlxG.width / 2 - logo.width / 2;
		logo.y = FlxG.height / 2 - logo.height / 2;
		
		FlxG.mouse.visible = false;
		FlxG.fixedTimestep = false;
		//FlxG.autoPause = false;
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
	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		
//#if debug
		startGame();
		return;
//#else
		// Do logo display/timing
		if (logotimer == 0)
		{
			FlxG.cameras.fade(0x00000000, 0.50, true);
			//FlxG.sound.play("assets/sounds/coin" + Reg.SoundExtension, 1, false);
		}

		if (logotimer >= 0)
			logotimer += elapsed;
			
		if (FlxG.keys.anyJustPressed(["SPACE", "ENTER", "C", "ESCAPE"]))
			logotimer = 2;
			
		
		if (logotimer >= 2)
		{
			logotimer = -1;
			FlxG.cameras.fade(0x00000000, 0.50, false, startGame);
		}
//#end
	}	

	private function startGame():Void
	{
		FlxG.switchState(new PlayState());
	}
}
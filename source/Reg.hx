package;

import entities.Player;
import flixel.group.FlxGroup;
import flixel.tile.FlxTilemap;
import flixel.util.FlxSave;
import entities.Rocket;
import flixel.FlxCamera;
import flixel.math.FlxPoint;

/**
 * Handy, pre-built Registry class that can be used to store 
 * references to objects and other things for quick-access. Feel
 * free to simply ignore it or change it in any way you like.
 */
class Reg
{
	public static inline var ROCKET_SPEED = 400;
	public inline static var ROCKET_COOLDOWN = 0.5;
	public static inline var PLAYER_DRAG = 450;
	public static inline var PLAYER_DRAG_AIR = 100;
	public inline static var PLAYER_MAX_SPEED = 150;
	public inline static var PLAYER_ACCEL = 15;
	public inline static var PLAYER_JUMP_VEL = 280;
	public inline static var PLAYER_SHOOT_Y_OFFSET = 10;
	public inline static var GRAVITY = 800;
	public inline static var JUMP_LENIENCE_TIMER = 0.2; //amount of time after hitting jump in which you'll automatically jump (bunnyhop) upon hitting the ground
	
	public inline static var ASSET_PATH_DATA = "assets/data/";
	public inline static var ASSET_PATH_IMAGES = "assets/images/";
	public inline static var ASSET_PATH_TILEMAPS = ASSET_PATH_IMAGES + "tilemaps/";

	public inline static var ASSET_EXT_IMAGE = ".png";

	public static var player:Player;
	public static var mapGroup:FlxGroup;
	public static var platforms:FlxGroup;
	public static var rockets:FlxGroup = new FlxGroup();
	public static var worldCam:FlxCamera;
	public static var hud:HUD;
	
	/**
	 * Destroy all rockets and clear the FlxGroup.
	 * @param	Reset	Whether or not to also destroy and recreate the FlxGroup. Only do this prior to a FlxState change as the group then needs to be re-added to the state.
	 */
	public static inline function destroyRockets(Reset:Bool):Void
	{
		for ( r in Reg.rockets )
			r.destroy();
			
		rockets.clear();
		
		if ( Reset )
		{
			rockets.destroy();
			rockets = new FlxGroup();
		}
	}
	
	public static inline function resetTimers():Void
	{
		levelTimerStarted = false;
		levelTimer = 0;
		
		if ( levelnum == 0 )
		{
			gameTimerStarted = false;
			gameTimer = 0;
		}
	}
	
	public static var levelnum:Int = 0;
	public static var leveltitle:String = "Level title";
	public static var levelnames:Array<String> = new Array<String>();
	public static var leveltitles:Array<String> = new Array<String>();
	public static var levelsloaded:Bool = false;
	public static var gameTimerStarted:Bool = false;
	public static var levelTimerStarted:Bool = false;
	public static var gameTimer:Float = 0; // total timer for entire game playthrough
	public static var levelTimer:Float = 0; // time for current level @TODO: make an array so we can show all level times at the end in a list
	
#if (native || windows)
	public inline static var shouldPixelPerfectRender:Bool = false;
#else
	public inline static var shouldPixelPerfectRender:Bool = true; //for whatever reason, this makes sprites jitter if false on flash target, and if true on windows target // TODO: is this still true?
#end
	
	public static inline function RemapValClamped( val:Float, A:Float, B:Float, C:Float, D:Float) : Float
	{
		if ( A == B )
			return val >= B ? D : C;
		var cVal:Float = (val - A) / (B - A);
		cVal = Clamp( cVal, 0.0, 1.0 );

		return C + (D - C) * cVal;
	}
	
	public static inline function Clamp( val:Float, minVal:Float, maxVal:Float ) : Float
	{
		if ( maxVal < minVal )
			return maxVal;
		else if( val < minVal )
			return minVal;
		else if( val > maxVal )
			return maxVal;
		else
			return val;
	}
	
	public static inline function Lerp( start:Float, end:Float, percent:Float )
	{
		return (start + percent * (end - start));
	}
	
	/**
	 * Generic levels Array that can be used for cross-state stuff.
	 * Example usage: Storing the levels of a platformer.
	 */
	public static var levels:Array<Dynamic> = [];
	/**
	 * Generic level variable that can be used for cross-state stuff.
	 * Example usage: Storing the current level number.
	 */
	public static var scores:Array<Dynamic> = [];
	/**
	 * Generic score variable that can be used for cross-state stuff.
	 * Example usage: Storing the current score.
	 */
	public static var score:Int = 0;
	/**
	 * Generic bucket for storing different FlxSaves.
	 * Especially useful for setting up multiple save slots.
	 */
	public static var saves:Array<FlxSave> = [];
}
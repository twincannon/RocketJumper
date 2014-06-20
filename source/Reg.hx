package;

import entities.Player;
import flixel.group.FlxGroup;
import flixel.tile.FlxTilemap;
import flixel.util.FlxSave;

import flixel.util.FlxPoint;

/**
 * Handy, pre-built Registry class that can be used to store 
 * references to objects and other things for quick-access. Feel
 * free to simply ignore it or change it in any way you like.
 */
class Reg
{
	public static inline var ROCKET_SPEED = 350;
	public inline static var ROCKET_COOLDOWN = 0.5;
	public static inline var PLAYER_DRAG = 500;
	public static inline var PLAYER_DRAG_AIR = 100;
	public inline static var PLAYER_MAX_SPEED = 150;
	public inline static var PLAYER_ACCEL = 15;
	public inline static var PLAYER_JUMP_VEL = 260;
	public inline static var PLAYER_JUMPHOLD_VEL = 3; //amount of vel to apply per-frame while holding jump (mario style)
	public inline static var PLAYER_JUMPHOLD_VEL_MOD = 0.02; //add "min(player.velocity.x, player_max_speed) * this" to jumphold vel
	public inline static var PLAYER_SHOOT_Y_OFFSET = 10;
	public inline static var GRAVITY = 800;

	public static var player:Player;
	public static var mapGroup:FlxGroup;
	
	public static var levelnum:Int = 0;
	public static var leveltitle:String = "Level title";
	public static var levelnames:Array<String> = new Array<String>();
	public static var leveltitles:Array<String> = new Array<String>();
	public static var levelsloaded:Bool = false;
	
	public static inline function RemapValClamped( val:Float, A:Float, B:Float, C:Float, D:Float) : Float
	{
		if ( A == B )
			return val >= B ? D : C;
		var cVal:Float = (val - A) / (B - A);
		cVal = clamp( cVal, 0.0, 1.0 );

		return C + (D - C) * cVal;
	}
	
	public static inline function clamp( val:Float, minVal:Float, maxVal:Float ) : Float
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
	
	/**
	 * Generic levels Array that can be used for cross-state stuff.
	 * Example usage: Storing the levels of a platformer.
	 */
	public static var levels:Array<Dynamic> = [];
	/**
	 * Generic level variable that can be used for cross-state stuff.
	 * Example usage: Storing the current level number.
	 */
	public static var level:Int = 0;
	/**
	 * Generic scores Array that can be used for cross-state stuff.
	 * Example usage: Storing the scores for level.
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
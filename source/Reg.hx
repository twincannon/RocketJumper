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
	public inline static var GRAVITY = 800;

	public static var player:Player;
	public static var mapGroup:FlxGroup;
	
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
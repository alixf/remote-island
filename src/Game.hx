import h2d.Anim;
import h2d.Bitmap;
import h2d.filter.Glow;
import h2d.Font;
import h2d.Sprite;
import h2d.SpriteBatch;
import h2d.Text;
import h2d.Tile;
import hxd.App;
import hxd.Key;
import hxd.Res;
import motion.Actuate;
import motion.easing.Linear;
import howler.Howl;
import howler.Howl.HowlOptions;

enum EntityType
{
	alfred;
	lisa;
	john;
	carlos;
	weakEnemy;
	mediumEnemy;
	strongEnemy;
	boss;
	snowman;
}

enum Action
{
	none;
	wait;
	info;
	attack;
	move;
}

enum TerrainType
{
	grass;
	water;
	forest;
	mountain;
}

class Game extends App
{
	public static var terrainWidth = 32;
	public static var terrainHeight = 25;
	public static var tileSize = 32;
	public static var tileScale = 2;
	
	public var dayText : Text;
	var cursorClock : Float;
	public var cursor : Cursor;
	public var map : Array < Array < { entity : Null<Entity>,
									   type : TerrainType,
									   tile : BatchElement,
									   overTile : BatchElement,
									   visTile : BatchElement,
									   visible : Bool,
									   practicable : Bool,
									   viewable : Bool,
									   marked : Bool} >> ;
	public var tilesheet : Array<Tile>;
	public var charsheet : Array<Tile>;
	public var team = new Array<Entity>();
	public var enemies = new Array<Entity>();
	public var neutrals = new Array<Entity>();
	public var terrain : SpriteBatch;
	public var terrainVisibility : SpriteBatch;
	public var terrainInfo : SpriteBatch;
	public var font : Font;
	public var okSound : Howl;
	public var cancelSound : Howl;
	public var nopeSound : Howl;
	public var attackSound : Howl;
	public var gameOverSound : Howl;
	public var music1 : Howl;
	public var music2 : Howl;
	public var icon : Bitmap;
	public var darkOverlay : Bitmap;
	public var fxLayer = new Sprite();
	public var entityLayer = new Sprite();
	public var gameOver = false;
	public var day = 0;
	
	public var storyStep = 0;
		
	static function main()
	{
		hxd.Res.initEmbed();
		new Game();
	}
	
	override function init() 
	{
		super.init();
		var charTile = hxd.Res.char1.toTile();
		font = hxd.Res.customFont.toFont();
		
		tilesheet = hxd.Res.tilesheet.toTile().grid(16);
		charsheet = hxd.Res.charsheet.toTile().grid(32);
		
		map = [for (x in 0...terrainWidth) { [for (y in 0...terrainHeight) { entity : null,
																			 type : TerrainType.grass,
																			 tile: null,
																			 overTile : null,
																			 visTile : null,
																			 visible : false,
																			 practicable : false,
																			 viewable : true,
																			 marked : false}]; } ];
		
		terrain = new SpriteBatch(tilesheet[0]);
		terrain.hasRotationScale = true;
		terrain.hasUpdate = true;
		terrainInfo = new SpriteBatch(tilesheet[0]);
		terrainInfo.hasRotationScale = true;
		terrainInfo.hasUpdate = true;
		terrainVisibility = new SpriteBatch(tilesheet[0]);
		terrainVisibility.hasRotationScale = true;
		terrainVisibility.hasUpdate = true;
		
		for (x in 0...terrainWidth)
		{
			for (y in 0...terrainHeight)
			{
				var ix = x - terrainWidth / 2;
				var iy = y - terrainHeight / 2;
				
				var tile = terrain.alloc(tilesheet[0]);
				tile.x = x * tileSize;
				tile.y = y * tileSize;
				tile.scale = tileScale;
				map[x][y].tile = tile;
				
				
				var overTile = terrainInfo.alloc(tilesheet[10]);
				overTile.x = x * tileSize;
				overTile.y = y * tileSize;
				overTile.scale = tileScale;
				map[x][y].overTile = overTile;
				
				var visTile = terrainVisibility.alloc(tilesheet[0]);
				visTile.x = x * tileSize;
				visTile.y = y * tileSize;
				visTile.scale = tileScale;
				map[x][y].visTile = visTile;
			}
		}
		loadTerrain(Res.level0);
		
		s2d.addChild(terrain);
		s2d.addChild(terrainInfo);
		s2d.addChild(terrainVisibility);
		
		var alfred = spawnEntity(0, 3, 22, 0, "Hi captain, I'm Alfred !");
		spawnEntity(1, 2, 20, 0, "Hello there, I'm Lisa !");
		spawnEnemy(4, 14, 11);
		
		spawnEntity(8, 10, 21, 3, "IN SUMMEEEER !");
		var carlos = spawnEntity(3, 28, 19, 3, "This is Carlos");
			
		
		s2d.addChild(entityLayer);
		s2d.addChild(fxLayer);
		
		cursor = new Cursor(this);
		s2d.addChild(cursor);
		cursor.gridX = 0;
		cursor.gridY = 24;
		
		s2d.addChild(new Bitmap(Res.overlay.toTile()));
		darkOverlay = new Bitmap(tilesheet[9]);
		darkOverlay.scaleX = Math.ceil(s2d.width / darkOverlay.tile.width);
		darkOverlay.scaleY = Math.ceil(s2d.height / darkOverlay.tile.height);
		darkOverlay.alpha = 0;
		s2d.addChild(darkOverlay);
		
		updateVisibility();
		
		dayText = new Text(font);
		dayText.text = "Day " + day;
		dayText.scale(3);
		dayText.x = 5;
		dayText.y = 5;
		s2d.addChild(dayText);
		
		music1 = new Howl( { urls : ["bgm/music1.mp3", "bgm/music1.ogg"], autoplay : true, loop : true } );
		music2 = new Howl( { urls : ["bgm/music2.mp3", "bgm/music2.ogg"], autoplay : false, loop : true } );
		okSound = new Howl({ urls : ["sfx/ok.mp3", "sfx/ok.ogg"], autoplay : false });
		cancelSound = new Howl({ urls : ["sfx/cancel.mp3", "sfx/cancel.ogg"], autoplay : false });
		nopeSound = new Howl({ urls : ["sfx/impossible.mp3", "sfx/impossible.ogg"], autoplay : false });
		attackSound = new Howl({ urls : ["sfx/attack.mp3", "sfx/attack.ogg"], autoplay : false });
		gameOverSound = new Howl({ urls : ["sfx/gameOver.mp3", "sfx/gameOver.ogg"], autoplay : false });
	}
	
	public function restart()
	{		
		team = new Array<Entity>();
		enemies = new Array<Entity>();
		neutrals = new Array<Entity>();
		fxLayer = new Sprite();
		gameOver = false;
		day = 0;
		storyStep = 0;
		music1.stop();
		music2.stop();
		for(child in s2d)
			s2d.removeChild(child);
		init();
	}
	
	public function proceedWithStory()
	{
		switch(storyStep)
		{
		case 0 :			
			Actuate.timer(2).onComplete(function()
			{
				team[0].showMessage("Hey captain ! Do you receive us ?\nPlace your cursor on me and hit [SPACE] please !");
			});
			storyStep++;
			
		case 1 :
			if (cursor.type == Cursor.CursorType.action && cursor.selection == team[0])
			{
				team[0].hideMessage();
				team[1].showMessage("Good job. Now press [RIGHT] to start moving.");
				storyStep++;
			}
			
		case 2 :
			if (cursor.type == Cursor.CursorType.selection && team[0].movedThisTurn)
			{
				team[1].hideMessage();
				team[1].showMessage("Our mission is to explore the area.", 2);
				storyStep++;
			}
			
		case 3 :
			if (!team[0].canMove() && !team[1].canMove())
			{
				team[1].hideMessage();
				team[1].showMessage("We won't do much more today.\nLet us rest by pressing [ENTER]", 5);
				storyStep++;
			}
			
			
		case 4 :
			if (enemies[0].scaleX > 0)
			{
				team[1].hideMessage();
				team[0].showMessage("Watch out ! This robot is aiming\nat us ! Attack it first !", 5);
				storyStep++;
			}
			
		case 5 :
			if (enemies[0].hp <= 0)
			{
				team[0].showMessage("The signal controlling this robot came\nfrom here ! Let's follow it !", 5);
				tilesheet[54] = tilesheet[54].center();
				this.icon = new Bitmap(tilesheet[54]);
				icon.x = 925;
				icon.y = 115;
				icon.setScale(5);
				Actuate.tween(icon, 0.5, { scaleX : 3, scaleY : 3 } ).repeat(5).onComplete(function()
				{
					s2d.removeChild(icon);
					icon = null;
				});
				s2d.addChild(icon);
				
				spawnEnemy(4, 28, 2);
				spawnEnemy(5, 28, 3);
				spawnEnemy(4, 29, 4);
				updateVisibility();
				
				storyStep++;
			}
			
		case 6 :
			for (enemy in enemies)
				if (enemy.hp > 0)
					return;
			
			if(map[24][3].entity == null)
				spawnEntity(2, 24, 3, 0, "I'm John. Thanks for saving me!");
			else if(map[23][3].entity == null)
				spawnEntity(2, 23, 3, 0, "I'm John. Thanks for saving me!");
			else if(map[22][3].entity == null)
				spawnEntity(2, 22, 3, 0, "I'm John. Thanks for saving me!");
			
			team[2].showMessage("Thanks for saving me guys ! I'm John\n I've been captured by these evil things some days ago!", 5);
			Actuate.timer(5.25).onComplete(function()
			{
				team[2].hideMessage();
				team[2].showMessage("I've located a strange signal south\nof here. We should head there.", 5);
			});
			
			spawnEnemy(5, 27, 19);
			spawnEnemy(6, 28, 18);
			updateVisibility();
			storyStep++;
			
		case 7 :
			for (enemy in enemies)
				if (enemy.hp > 0)
					return;
			
			team[2].showMessage("This is Carlos, he's dead already :(\nWait! Something is writting on his arm", 5);
			Actuate.timer(5.25).onComplete(function()
			{
				team[2].hideMessage();
				team[2].showMessage("\"They come from the dark forest\"\nI know this place, this is north of here! Let's go!", 5);
				music1.stop();
				music2.volume(0.33);
				music2.play();
			});
			
			spawnEnemy(4, 21, 10);
			spawnEnemy(5, 18, 12);
			spawnEnemy(4, 18, 2);
			spawnEnemy(6, 18, 4);
			spawnEnemy(5, 9, 3);
			spawnEnemy(6, 4, 6);
			spawnEnemy(7, 4, 4);
			updateVisibility();
			
			storyStep++;
			
		case 8 :
			for (enemy in enemies)
				if (enemy.hp > 0)
					return;
			
			team[0].showMessage("Finally we did it ! The island is now clean.", 5);
			Actuate.timer(5.25).onComplete(function()
			{
				team[0].hideMessage();
				team[2].showMessage("I don't think so ... but let's head back to the base.", 5);
				
				Actuate.timer(5.25).onComplete(function()
				{
					storyStep++;
				});
			});
			
		case 9 : 
			Actuate.stop(darkOverlay);
			Actuate.update(function(a : Float) { darkOverlay.alpha = a; }, 2, [darkOverlay.alpha], [1]);
			
			var gameOverText = new Text(font);
			gameOverText.text = "Your cleared the area ...\n           Good Job Captain!";
			gameOverText.scale(3);
			gameOverText.x = s2d.width/2-gameOverText.textWidth;
			gameOverText.y = s2d.height/2-gameOverText.textHeight/2;
			s2d.addChild(gameOverText);
			Actuate.update(function(a : Float) { gameOverText.alpha = a; }, 2, [0.0], [1]);
				
		default:
		}
	}
	
	override function update(dt:Float)
	{
		proceedWithStory();
		
		if (Key.isPressed(Key.ENTER) && !gameOver)
			goToNextTurn();
			
		super.update(dt);
		// clear cache
		dayText.x = dayText.x;
		cursor.x = cursor.x;
		cursor.update(dt);
		darkOverlay.alpha = darkOverlay.alpha;
		for (fx in fxLayer)
		{
			var tmp = Std.instance(fx, AnimatedBitmap);
			if (tmp != null)
				tmp.update(dt);
		}
		
		if (icon != null)
			icon.x = icon.x;
		
		for(character in team)
			character.update(dt);
			
		for(character in enemies)
			character.update(dt);
			
		for (character in neutrals)
			character.update(dt);
			
		if (Key.isPressed(Key.SPACE) && gameOver)
		{
			restart();
		}
	}
	
	public function goToNextTurn()
	{
		day++;
		Actuate.tween(dayText, 0.5, { y : -2*dayText.textHeight, alpha : 1.0 } ).onComplete(function()
		{
			dayText.text = "Day "+day;
			Actuate.tween(dayText, 0.5, { y : 5, alpha : 1.0 } );
		});
		
		for (enemy in enemies)
		{
			if (enemy.hp > 0)
			{
				for (character in team)
				{
					if (character.hp > 0)
					{
						if (Math.abs(enemy.gridX - character.gridX) + Math.abs(enemy.gridY - character.gridY) <= enemy.attackRange)
						{
							enemy.attack(character);
							break;
						}
					}
				}
			}
		}
		
		gameOver = false;
		for (character in team)
		{
			character.resetTurn();
			if (character.hp <= 0)
			{
				gameOver = true;
				Actuate.stop(darkOverlay);
				Actuate.update(function(a : Float) { darkOverlay.alpha = a; }, 2, [darkOverlay.alpha], [1]);
				
				var gameOverText = new Text(font);
				gameOverText.text = "One of your soldiers is dead ...\n           Press [SPACE] to restart.";
				gameOverText.scale(3);
				gameOverText.x = s2d.width/2-gameOverText.textWidth;
				gameOverText.y = s2d.height/2-gameOverText.textHeight/2;
				s2d.addChild(gameOverText);
				Actuate.update(function(a : Float) { gameOverText.alpha = a; }, 2, [0.0], [1]);
				music1.stop();
				music2.stop();
				gameOverSound.play();
			}
		}
		if (!gameOver)
		{		
			Actuate.update(function(a : Float) { darkOverlay.alpha = a; }, 0.5, [0], [0.75] ).onComplete(function()
			{
				Actuate.update(function(a : Float) { darkOverlay.alpha = a; }, 0.5, [0.75], [0] );
			});	
		}
	}
	
	public function spawnEntity(type : Int, x : Int, y : Int, team : Int, info : String)
	{
		var entity = new Entity(this);
		var abmp = new AnimatedBitmap(charsheet, [0 + type * 10, 1 + type * 10], 0.5);
		entity.abmp = abmp;
		entity.addChild(abmp);
		entity.type = type;
		entity.gridX = x;
		entity.gridY = y;
		entity.team = team;
		entity.info = info;
		entity.filters = [new Glow(0x000000, 255, 1)];
		entityLayer.addChild(entity);
		
		if(team == 0)
			this.team.push(entity);
		if(team == 1)
			enemies.push(entity);
		else
			neutrals.push(entity);
		
		switch(type)
		{
		case 0: // Alfred
			entity.hp = 8;
			entity.initialHP = 8;
			entity.attackRange = 3;
			entity.firePower = 4;
		case 1: // Lisa
			entity.hp = 10;
			entity.initialHP = 10;
			entity.attackRange = 4;
			entity.firePower = 2;
		case 2: // John
			entity.hp = 7;
			entity.initialHP = 7;
			entity.attackRange = 1;
			entity.firePower = 8;
		case 3: // Carlos
			entity.hp = 0;
			entity.initialHP = 0;
			entity.attackRange = 0;
			entity.firePower = 0;
		case 4: // Type-1
			entity.hp = 10;
			entity.initialHP = 10;
			entity.attackRange = 3;
			entity.firePower = 4;
		case 5: // Type-2
			entity.hp = 20;
			entity.initialHP = 20;
			entity.attackRange = 5;
			entity.firePower = 2;
		case 6: // Type-3
			entity.hp = 10;
			entity.initialHP = 10;
			entity.attackRange = 3;
			entity.firePower = 9;
		case 7: // Type-4
			entity.hp = 50;
			entity.initialHP = 50;
			entity.attackRange = 5;
			entity.firePower = 5;
		case 8: // Snowman
			entity.hp = 99;
			entity.initialHP = 99;
			entity.attackRange = 99;
			entity.firePower = 99;
		default:
		}
			
		return entity;
	}
	
	public function spawnEnemy(type : Int, x : Int, y : Int)
	{
		spawnEntity(type, x, y, 1, "This is an enemy unit.");
	}
	
	public function showMoveRadius(x, y, radius)
	{
		for (ix in 0...terrainWidth)
		{
			for (iy in 0...terrainHeight)
			{
				if (Math.abs((x-ix)) + Math.abs((y-iy)) <= radius && map[ix][iy].practicable)
					map[ix][iy].overTile.t = tilesheet[11];
				else
					map[ix][iy].overTile.t = tilesheet[12];
			}
		}
	}
	
	public function showAttackRadius(x, y, radius)
	{
		for (ix in 0...terrainWidth)
		{
			for (iy in 0...terrainHeight)
			{
				if (Math.abs((x-ix)) + Math.abs((y-iy)) <= radius)
					map[ix][iy].overTile.t = tilesheet[13];
				else
					map[ix][iy].overTile.t = tilesheet[12];
			}
		}
	}
	
	public function checkBounds(x, y)
	{
		return (x >= 0 && y >= 0 && x < terrainWidth && y < terrainHeight);
	}
	
	public function updateVisibility()
	{
		for (x in 0...terrainWidth)
		{
			for (y in 0...terrainHeight)
			{
				map[x][y].visTile.t = tilesheet[12];
				map[x][y].visible = false;
				map[x][y].marked = false;
			}
		}
		
		for (character in team)
		{
			map[character.gridX][character.gridY].visible = true;
			map[character.gridX][character.gridY].visTile.t = tilesheet[0];
			
			if (map[character.gridX][character.gridY].type == TerrainType.forest)
			{
				map[character.gridX - 1][character.gridY].visible = map[character.gridX - 1][character.gridY].visible || map[character.gridX - 1][character.gridY].practicable;
				map[character.gridX - 1][character.gridY].visTile.t = tilesheet[map[character.gridX - 1][character.gridY].visible ? 0 : 12];
				map[character.gridX + 1][character.gridY].visible = map[character.gridX + 1][character.gridY].visible || map[character.gridX + 1][character.gridY].practicable;
				map[character.gridX + 1][character.gridY].visTile.t = tilesheet[map[character.gridX + 1][character.gridY].visible ? 0 : 12];
				map[character.gridX][character.gridY - 1].visible = map[character.gridX][character.gridY - 1].visible  || map[character.gridX][character.gridY - 1].practicable;
				map[character.gridX][character.gridY - 1].visTile.t = tilesheet[map[character.gridX][character.gridY - 1].visible ? 0 : 12];
				map[character.gridX][character.gridY + 1].visible = map[character.gridX][character.gridY + 1].visible || map[character.gridX][character.gridY + 1].practicable;
				map[character.gridX][character.gridY + 1].visTile.t = tilesheet[map[character.gridX][character.gridY + 1].visible ? 0 : 12];
			}
			else
			{
				// left line
				var x = character.gridX-1;
				var y = character.gridY;
				while (x > character.gridX - character.viewRadius-1 && checkBounds(x, y))
				{
					map[x][y].visible = map[x][y].visible || (map[x + 1][y].visible && map[x][y].viewable);
					map[x][y].visTile.t = tilesheet[map[x][y].visible ? 0 : 12];
					x--;
				}
				// right line
				var x = character.gridX+1;
				var y = character.gridY;
				while (x < character.gridX+character.viewRadius+1 && checkBounds(x, y))
				{
					map[x][y].visible = map[x][y].visible || (map[x - 1][y].visible && map[x][y].viewable);
					map[x][y].visTile.t = tilesheet[map[x][y].visible ? 0 : 12];
					x++;
				}
				// top line
				var x = character.gridX;
				var y = character.gridY-1;
				while (y > character.gridY - character.viewRadius-1 && checkBounds(x, y))
				{
					map[x][y].visible = map[x][y].visible || (map[x][y + 1].visible && map[x][y].viewable);
					map[x][y].visTile.t = tilesheet[map[x][y].visible ? 0 : 12];
					y--;
				}
				// bottom line
				var x = character.gridX;
				var y = character.gridY+1;
				while (y <= character.gridY + character.viewRadius && checkBounds(x, y))
				{
					map[x][y].visible = map[x][y].visible || (map[x][y - 1].visible && map[x][y].viewable);
					map[x][y].visTile.t = tilesheet[map[x][y].visible ? 0 : 12];
					y++;
				}
				// top-left corner
				var x = character.gridX-1;
				while(Math.abs(x-character.gridX) <= character.viewRadius)
				{
					y = character.gridY-1;
					while(Math.abs(y-character.gridY) <= character.viewRadius)
					{
						if (Math.abs(character.gridX - x) + Math.abs(character.gridY - y) <= character.viewRadius && checkBounds(x, y))
						{
							map[x][y].visible = map[x][y].visible || (map[x][y].viewable && map[x + 1][y].visible && map[x][y + 1].visible);
							map[x][y].visTile.t = tilesheet[map[x][y].visible ? 0 : 12];
						}
						y--;
					}
					x--;
				}
				// top-right corner
				var x = character.gridX+1;
				while(Math.abs(x-character.gridX) <= character.viewRadius)
				{
					y = character.gridY-1;
					while(Math.abs(y-character.gridY) <= character.viewRadius)
					{
						if (Math.abs(character.gridX - x) + Math.abs(character.gridY - y) <= character.viewRadius && checkBounds(x, y))
						{
							map[x][y].visible = map[x][y].visible || (map[x][y].viewable && map[x - 1][y].visible && map[x][y + 1].visible);
							map[x][y].visTile.t = tilesheet[map[x][y].visible ? 0 : 12];
						}
						y--;
					}
					x++;
				}
				// bottom-left corner
				var x = character.gridX-1;
				while(Math.abs(x-character.gridX) <= character.viewRadius)
				{
					y = character.gridY+1;
					while(Math.abs(y-character.gridY) <= character.viewRadius)
					{
						if (Math.abs(character.gridX - x) + Math.abs(character.gridY - y) <= character.viewRadius && checkBounds(x, y))
						{
							map[x][y].visible = map[x][y].visible || (map[x][y].viewable && map[x + 1][y].visible && map[x][y -1].visible);
							map[x][y].visTile.t = tilesheet[map[x][y].visible ? 0 : 12];
						}
						y++;
					}
					x--;
				}
				// bottom-right corner
				var x = character.gridX+1;
				while(Math.abs(x-character.gridX) <= character.viewRadius)
				{
					y = character.gridY+1;
					while(Math.abs(y-character.gridY) <= character.viewRadius)
					{
						if (Math.abs(character.gridX - x) + Math.abs(character.gridY - y) <= character.viewRadius)
						{
							if (!checkBounds(x, y))
								break;
							map[x][y].visible = map[x][y].visible || (map[x][y].viewable && map[x - 1][y].visible && map[x][y - 1].visible);
							map[x][y].visTile.t = tilesheet[map[x][y].visible ? 0 : 12];
						}
						y++;
					}
					x++;
				}
			}
		}
		
		for (enemy in enemies)
		{
			if (map[enemy.gridX][enemy.gridY].visible && enemy.hp > 0)
				enemy.setScale(1);
			else
				enemy.setScale(0);
		}
		
		for (neutral in neutrals)
		{
			if (map[neutral.gridX][neutral.gridY].visible)
				neutral.setScale(1);
			else
				neutral.setScale(0);
		}
	}
	
	public function hideOverTile()
	{
		for (ix in 0...terrainWidth)
			for (iy in 0...terrainHeight)
				map[ix][iy].overTile.t = tilesheet[10];
	}
	
	public function showPath(path : Array<{x : Int, y : Int}>)
	{
		for (i in 0...path.length)
		{
			var pos = path[i];
			
			if (i == 0)
				map[pos.x][pos.y].overTile.t = tilesheet[14];
			
			else if(i == path.length-1)
			{
				var prevPos = path[i - 1];
				
				if (pos.x - prevPos.x == -1)
					map[pos.x][pos.y].overTile.t = tilesheet[28];
				else if (pos.x - prevPos.x == 1)
					map[pos.x][pos.y].overTile.t = tilesheet[26];
				else if (pos.y - prevPos.y == -1)
					map[pos.x][pos.y].overTile.t = tilesheet[29];
				else
					map[pos.x][pos.y].overTile.t = tilesheet[27];
			}
			else
			{
				var prevPos = path[i - 1];
				var nextPos = path[i + 1];
				
				if (nextPos.y - prevPos.y == 0)
					map[pos.x][pos.y].overTile.t = tilesheet[20];
				else if (nextPos.x - prevPos.x == 0)
					map[pos.x][pos.y].overTile.t = tilesheet[21];
					
				if (pos.x - prevPos.x == -1)
				{
					if(nextPos.y-pos.y == -1)
						map[pos.x][pos.y].overTile.t = tilesheet[24];
					if(nextPos.y-pos.y == 1)
						map[pos.x][pos.y].overTile.t = tilesheet[22];
				}
				else if (pos.x - prevPos.x == 1)
				{
					if(nextPos.y-pos.y == -1)
						map[pos.x][pos.y].overTile.t = tilesheet[25];
					if(nextPos.y-pos.y == 1)
						map[pos.x][pos.y].overTile.t = tilesheet[23];
				}
				else if (pos.y - prevPos.y == -1)
				{
					if(nextPos.x-pos.x == -1)
						map[pos.x][pos.y].overTile.t = tilesheet[23];
					if(nextPos.x-pos.x == 1)
						map[pos.x][pos.y].overTile.t = tilesheet[22];
				}
				else
				{
					if(nextPos.x-pos.x == -1)
						map[pos.x][pos.y].overTile.t = tilesheet[25];
					if(nextPos.x-pos.x == 1)
						map[pos.x][pos.y].overTile.t = tilesheet[24];
				}
			}
		}
	}
	
	public function hidePath(path : Array<{x : Int, y : Int}>)
	{
		for (pos in path)
			map[pos.x][pos.y].overTile.t = tilesheet[11];
	}
	
	public function loadTerrain(level)
	{
		var waterTiles = [];
		for (x in 0...terrainWidth)
		{
			for (y in 0...terrainHeight)
			{
				switch(level.getPixels().getPixel(x, y))
				{
				case 0xFF0000FF :
					map[x][y].tile.t = tilesheet[2];
					map[x][y].practicable = false;
					map[x][y].type = TerrainType.water;
					waterTiles.push(map[x][y].tile);
					
				case 0xFF00FF00:
					var continuousMask = [
						level.getPixels().getPixel(x, y-1) == 0xFF0000FF ? 0 : 1,
						level.getPixels().getPixel(x+1, y) == 0xFF0000FF ? 0 : 1,
						level.getPixels().getPixel(x, y+1) == 0xFF0000FF ? 0 : 1,
						level.getPixels().getPixel(x-1, y) == 0xFF0000FF ? 0 : 1
					];
					var offset = switch(continuousMask)
					{
					case [1, 1, 1, 1] : 16+Std.random(4);
					case [0, 1, 1, 0] : 1;
					case [0, 0, 1, 1] : 2;
					case [1, 1, 0, 0] : 3;
					case [1, 0, 0, 1] : 4;
					case [0, 1, 1, 1] : 5;
					case [1, 1, 0, 1] : 6;
					case [1, 1, 1, 0] : 7;
					case [1, 0, 1, 1] : 8;
					case [0, 0, 0, 0] : 9;
					case [0, 1, 0, 1] : 10;
					case [1, 0, 1, 0] : 11;
					case [0, 0, 1, 0] : 12;
					case [0, 0, 0, 1] : 13;
					case [0, 1, 0, 0] : 14;
					case [1, 0, 0, 0] : 15;
					case _ : 0;
					};
					map[x][y].tile.t = tilesheet[30 + offset];
					map[x][y].practicable = true;
					map[x][y].practicable = true;
					map[x][y].type = TerrainType.grass;
					
				case 0xFF008000	:
					map[x][y].tile.t = tilesheet[6+Std.random(3)];
					map[x][y].viewable = false;
					map[x][y].practicable = true;
					map[x][y].type = TerrainType.forest;
					
				case 0xFF633a00 :
					map[x][y].tile.t = tilesheet[16 + Std.random(3)];
					map[x][y].viewable = false;
					map[x][y].practicable = false;
					map[x][y].type = TerrainType.mountain;
					
				
				default :
					map[x][y].tile.t = tilesheet[30];
					map[x][y].practicable = true;
					map[x][y].practicable = true;
					map[x][y].type = TerrainType.grass;
				}
			}
		}
		
	// Animate water
	Actuate.update(function updateWater(i : Int)
	{
		var array = [2, 3, 4, 5];
		var tile = tilesheet[array[Math.floor(i)]];
		if (tile != null)
		{
			for (e in waterTiles)
			{
				e.t = tile;
			}
		}
	}, 2, [0], [4]).ease(Linear.easeNone).repeat();
	}
}
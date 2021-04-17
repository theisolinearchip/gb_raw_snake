# gb_raw_snake
A small raw snake game from Game Boy written in ASM.

![Snake 1](http://albertgonzalez.coffee/projects/raw_snake/img/snake_1_small.png) ![Snake 2](http://albertgonzalez.coffee/projects/raw_snake/img/snake_2_small.png) ![Snake 3](http://albertgonzalez.coffee/projects/raw_snake/img/snake_3_small.png)

This is my first "full project" for the GB platform and also my first assembly-only software. It's a raw port of the classic **Snake** game made to learn more about writting ASM code (the last time I used it was back in the days when I was in college :_ D) and to understand the **Game Boy** better (reading the docs is okay, but I think the best way to really _know_ about these things is to try and tinker with them). It's assembled with [RGBDS](https://github.com/gbdev/rgbds).

The game has a simple title screen and a never-leaving 19 x 17 "playable" grid. The Game Boy shows a 20 x 19 tiles grid on the screen and without the borders we have a max number of 275 possible "snake segments" on a run (**but** the max amount will be 255 since we're storing the length info in a single RAM space -8 bits-; this could be improved by using a pair instead of only one).

## Game features

- Same speed. Always!
- There's no "extra step" when you're about to collide to something : (
- No sound!
- Max limit of 255 items collected! : D
- One title screen, one playable grid in an endless loop!
- Homemade tiles! (I made a small web utility to tinker with sprites, loosely inspired by the [Game Boy Tile Designer](http://www.devrs.com/gb/hmgd/gbtd.html))
- No hi-score saving!

## Snake as background

The playable grid only shows five sprites: three score digits, the snake head and the item. The body segments are **background tiles** that are changed on every "step" to make the movement happen. Since the max sprites on screen are 40 (10 max per line) it's impossible to build a snake made of _sprites_ (even with some techniques I read about allowing more than 40 sprites at the same time, but then again, the max amount is not enough for our purposes) so I took the background approach.

There's a block of RAM that stores info about each valid grid tile: 0 for an empty space and some integer > 0 for a segment. On each step the "head" moves one position and, in that space, a new segment is created by changing its index into a number equal to the current segment count. After that, all of the index values > 0 are decremented by 1, creating the illusion of movement by slowly removing the values that are reaching 0 (the "tail" one).

After this index adjustment the background redraws the index positions that became 0 (changing a segment tile by an empty one) and draws the new segment that changes from 0 to the current segment count.

(and if the player reaches an item the current segment count is increased and this loop check ommited, allowing the snake to "grow" one position without decrementing anything).

This approach works fine, but there's an interesting memory allocation issue based on the _real grid_ we're dealing with:

- The full tiles grid is actually a 32 x 32 one, meaning that there's "space on the right" that we're not using (I'm not dealing with scrolls nor anything similar here).
- The RAM block that store those index represent the full grid from the beginning (0-0, the top-left wall corner on our screen) to the last valid position for the player (19-17, the last empty space in the bottom-right corner; it's pointless to save space for the down walls).

Translating a grid element into an element for the list works fine because the coordinates works into that 32 x 32 space **but** it's obvious that we're creating some "unused gaps" in the RAM for those tiles between 21 and 32 on each line.

A different approach could be based on a "translate function" that can allocate ONLY the used tiles in the index list with a method to jump from one line to another. I think this can be slower than just iterating over a big list, and since this is a small game, it works (but in a more big project this needs to be, at least, revised).

Also, this continuous "checking for the background" method uses the VRAM access all the time, and the **vblanks periods** are checked all the time. I'm not sure this is the best way to handle this in this particular hardware (I mean, it works and waits for each vblank period in order to update the background, but I cannot stop thinking about better ways to do it without having to wait each time for a "background check").

## Interrupts for the controls

On each step the joypad interrupt listens for **one** pushed button and then it's disabled until the next step. This mean you can change the direction one time per step on almost every moment, _except_ when checking the background, since it seems it can cause some troubles while accessing the VRAM during a vblank period. This works pretty fine, but the timming needs to be right!

This can be probably improved while keeping the "one push button at any time causes a direction change on the next step" functionality.

## In conclusion

So the game is "completed": this means I've learned lots of things while doing it (things I didn't know how to do, things I've managed to solve, things I know that aren't perfect but are _enough_ for the scope of this project, etc.) and I call it a success! But:

- This is more of a tech test/challenge rather than a _fun game_. I mean, you can play it and compete with your friends or yourself if you want, but chances are you're going to get bored quickly :/
- My ASM skills are probably _bad_. I've read a lot about how to organize your code, best practises when working with a Game Boy, etc. But in the end I need more practise.
- My Game Boy knowledge was almost zero before doing this. I read some things and tried a couple of ideas before, but this is the first _complete_ software I wrote. Again, more practise! (and try new things like scrolling, poking with more interruptions, the sound, etc.)

## Play the game

I'll check for an online emulator or something that allows the rom to be played in a browser. Meanwhile you can download the **snake.gb** rom that is available here.

Or you can compile the source with the [https://github.com/gbdev/rgbds](https://github.com/gbdev/rgbds) **RGBDS** tools using the provided **Makefile**.

## Links
[https://gbdev.io/pandocs](https://gbdev.io/pandocs) **Pan Docs**, probably the best Game Boy technical reference document

[https://gbdev.io](https://gbdev.io) Game Boy Development comunity

[https://eldred.fr/gb-asm-tutorial/](https://eldred.fr/gb-asm-tutorial/) An very interesting Game Boy ASM tutorial. I made my first Hello World with it! :D The **hardware.inc** file with some definitions is from here

[http://wiki.ladecadence.net/doku.php?id=tutorial_de_ensamblador](http://wiki.ladecadence.net/doku.php?id=tutorial_de_ensamblador) Another Game Boy ASM tutorial (in spanish) with lots of info and details

[https://github.com/gbdev/rgbds](https://github.com/gbdev/rgbds) **RGBDS** github page

[https://bgb.bircd.org/](https://bgb.bircd.org/) **BGB Game Boy emulator and debugger** (for Windows only, but works great on Wine too!)

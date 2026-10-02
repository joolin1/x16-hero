# x16-hero

A sequel to the classic game H.E.R.O. originally for Commodore 64 and Atari.

This version is for **Commander X16**.

## Download and play

- **Commander X16:** [Download the game and try it in a web emulator](https://cx16forum.com/forum/viewtopic.php?t=6912).

### Apple II VERA Platform — port by anomixer

The game is also available for the **Apple II VERA Platform**, thanks to **[anomixer](https://github.com/anomixer)**, who ported it to this platform.

- [Visit anomixer's Apple II VERA port](https://github.com/anomixer/x16-hero-vera).
- [Play the Apple II VERA version in your browser](https://apple2ts.com/?theme=dark&slot2=vera&tab=vera#https://raw.githubusercontent.com/anomixer/x16-hero-vera/main/x16-hero-vera.hdv).

## Goal

Your mission is to search several mines and find the miner that is trapped in each of them.

## Equipment

Fortunately, you have some equipment when setting out on your mission. This is what you have:

1. **Backpack helicopter:** A backpack helicopter to make you fly. After a short while you will start to lose height if you don't accelerate upwards.
2. **Helmet laser:** An integrated helmet laser that will effectively kill every living thing that threatens your life.
3. **Dynamite:** Unlimited number of dynamite bars to blow certain rocks and walls up. Just move away fast to avoid getting killed in the blast.

## Dangers

There are lots of creatures threatening to kill you: hunting bats, poisonous spiders, biting snakes, carnivorous plants, and alien creatures that no one knows what it really is. As if that wasn't enough, some rocks contain magma sediments. They glow red and must not be touched.

## Torches

There are torches on the walls that illuminate the mines. If you touch one of them all torches go out leaving you in darkness. Touch another and all will be ignited again.

## Controls

### When walking

| Control | Action |
| --- | --- |
| A button (`X` or `Left Ctrl`) | Fire laser |
| B button (`Z` or `Left Alt`) | Place and ignite a bar of dynamite |
| Up | Start flying |
| Left / Right | Walk in the indicated direction |

If you step over an edge to a shaft, you will fall. It won't hurt you, but watch out where you land.

### When flying

| Control | Action |
| --- | --- |
| A button (`X` or `Left Ctrl`) | Fire laser |
| Up | Fly upwards and extend the time before you start losing altitude |
| Left / Right / Down | Fly in the indicated direction |

You cannot crash, when you reach the ground, your hero will land.

### Pausing the game

Pause the game by pressing the **Start** button (`Enter`). A dialog opens where you can choose to resume the game or quit.

## High-score table and start level

The high-score table is highly relevant. If you earn a spot, the next time you play, you can choose to start at the level you reached (or one of the levels below). The drawback of starting at a higher level is that it reduces your chances of reaching the high-score table again. You skip the easily saved miners on the lower levels.

The number of saved miners matters the most when trying to earn a spot on the high-score table. Time is only relevant when it comes to distinguishing between two players who have saved as many miners.

## Completing the game

You have 5 lives. For each completed level you get one extra life if you have less than 5 left. There are ten levels in the game. Can you complete them all?

## Running the game with the emulator

Run the emulator from the folder where all the game files are located:

```sh
x16Emu -prg mine.prg -run -joy1
```

If a game controller is connected this is what you use for playing otherwise the keyboard.

## Releases

### Version 1.0.1 — March 24, 2024

A minor bug has been corrected and the faster walking speed is removed. It kicked in when the player had walked a certain distance but was more confusing than helpful.

### Version 1.0 — November 6, 2023

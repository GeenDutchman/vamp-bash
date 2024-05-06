# Vampire Game

This is a game inspired by a (flash?) game that I saw my dad play online a long time ago.  I have two other, older implementations in [c++](https://github.com/GeenDutchman/vamp-mummy-game-c-plus-plus) and [python notebook](https://github.com/GeenDutchman/vamp_learn).

## Gameplay

```plaintext
████████████████████
██ ███   █  ██     █
█ █ █       █  █   █
█   ███#         █ █
█        █         █
█         ██ █ █   █
█                  █
██         █       █
█       █    █    ██
█    █         █████
█               ██ █
█  █ █ █ █  @█     █
█  █      █        █
██   █ M     V █  ██
█ █    W    █      █
█ █    █ █         █
█   █        █    ██
█     ███    █ █   █
██      █          █
████████████████████
```

Essentially, the player (Visualized by a `#`) is in a maze of randomly generated walls (visualized by `█`).  The Player is trying to get to the Goal (visualized by `@`) and getting there will take them to the next level.  However, there are monsters out there who are out to get the player.  If they get you it is **Game Over**. So far I have

- Vampire: `V`  
 Moves **twice** for every one move that the player makes.
- Mummy: `M`  
 Leaves behind wrappings `W` that only Mummies can walk through.

As the levels progress, more Vampires and Mummies are generated.

## Entity Ideas

I'd also like to make the following entities:

- Hunter: `H`  
Ally to the player, eliminates Vampires.
- Ghost: `G`  
Can go through walls and wrappings, BUT moves once for every **two** moves the player makes.
- Vampire Lord: `L`  
Uses smarter decisions to reach the player.

## Mechanics

Each item in the map has a hardness, or `mohs` value.  An item can only be placed onto a location if that location either has no items, or the individual items at that location have a strictly *lower* `mohs` value than the new item.

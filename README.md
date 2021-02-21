# [Humerus Decks]

Humerus Decks is a fork of [Massive Decks](https://github.com/lattyware/massivedecks), a free, open source comedy party game based on [Cards against Humanity][cah], with an AI twist! Play with friends!
Play against the [Humerus bot](https://github.com/UTMIST/Humerus)! Are you funnier than a computer?

[cah]: https://cardsagainsthumanity.com/



## Features

 - Play together in the same room or online.
 - Use any device (Phone, PC, Chromecast, anything with a web browser).
 - You can set up a central screen, but you don't need to (no need to stream anything for other players online).
 - Custom decks (via [Many Decks][many-decks]).
 - Customise the rules:
   - Custom cards.
   - House rules.
   - AI players.
   - Custom time limits if you want them.
 - Spectators.
 - Keeps your game private by default, you can also set a game password if needed.
 - Community translations.

[many-decks]: https://decks.rereadgames.com/

## About

The game is open source software available under [the AGPLv3 license](LICENSE).

The web client for the game is written in [Elm][elm], while the back-end is written in [Typescript][typescript].

[elm]: https://elm-lang.org/
[typescript]: https://www.typescriptlang.org/

## Deploying

If you would like to run a production instance of Massive Decks, there are a couple of options.

It is suggested you read the [deployment guide on the wiki][deployment-guide].

[deployment-guide]: https://github.com/Lattyware/massivedecks/wiki/Deploying

### Docker

The Docker images can be found on Docker Hub: [Server](https://hub.docker.com/r/massivedecks/server) / [Client](https://hub.docker.com/r/massivedecks/client).

## Contributing

If you have any problems with the game, please [raise an issue][issue]. 
Contribution guide coming soon!

## Credits

### Maintainers

[Brian Chen](https://chenbrian.ca)

### Inspiration

The 'Cards against Humanity' game concept is used under a [Creative Commons BY-NC-SA 2.0 license][cah-license] granted
by [Cards against Humanity][cah].

[cah-license]: https://creativecommons.org/licenses/by-nc-sa/2.0/

Massive Decks is also inspired by:
* [CardCast][cardcast] - an app that allowed you to play on a Chromecast, now dead.
* [Pretend You're Xyzzy][xyzzy] - another web implementation.

[cardcast]: https://www.cardcastgame.com/
[xyzzy]: http://pretendyoure.xyz/zy/

import * as Source from "../source";
import http, { AxiosRequestConfig } from "axios";
import * as Config from "../../../config";
import { SourceNotFoundError } from "../../../errors/action-execution-error";
import * as Decks from "../decks";
import * as Card from "../card";

/**
 * From JSON Against Humanity (https://crhallberg.com/cah/)
 */
export interface JsonAgainstHumanity {
  source: "JAH";
  id: string;
}

export interface ClientInfo {
  aboutUrl: string;
  decks: {
    id: string;
    name: string;
  }[];
}

interface RawDecks {
  cards: {
    white: { text: string }[];
    black: { text: string; pick: number }[];
  };
  decks: { [id: string]: RawDeck };
}

interface RawDeck {
  name: string;
  description: string;
  official: boolean;
  icon: string | number;
  white: number[];
  black: number[];
}

const endsSentence = new Set([".", "!", "?"]);

function* introduceSlots(line: string): Iterable<Card.Part> {
  const lineParts = line.split("_");
  let nextSlot: Card.Part | undefined = undefined;
  for (const part of lineParts) {
    if (nextSlot !== undefined) {
      yield nextSlot;
    }
    yield part;
    const last = part.trimRight().substr(-1);
    if (part === "" || endsSentence.has(last)) {
      nextSlot = { transform: "Capitalize" };
    } else {
      nextSlot = {};
    }
  }
}

function rawDeckToSummaryAndTemplates(
  raw: RawDecks,
  id: string
): {
  summary: Source.Summary;
  templates: Decks.Templates;
} {
  const pack = raw.decks[id];

  const source: JsonAgainstHumanity = {
    source: "JAH",
    id,
  };

  function call(index: number): Card.Call {
    const from = raw.cards.black[index];
    const parts = from.text.split("\n").map((t) => [...introduceSlots(t)]);
    const slots = Card.slotCount(parts);
    const extraSlots = Math.max(0, from.pick - slots);
    return {
      id: Card.id(),
      source,
      parts: [...parts, ...Array(extraSlots).fill([{}])],
    };
  }

  function response(index: number): Card.Response {
    const from = raw.cards.white[index];
    const stripped = from.text.replace("\n", "");
    return {
      id: Card.id(),
      source,
      text: stripped.endsWith(".")
        ? stripped.substr(0, stripped.length - 1)
        : stripped,
    };
  }

  return {
    summary: {
      details: { name: pack.name },
      calls: pack.black.length,
      responses: pack.white.length,
    },
    templates: {
      calls: new Set(pack.black.map(call)),
      responses: new Set(pack.white.map(response)),
    },
  };
}

export class Resolver extends Source.Resolver<JsonAgainstHumanity> {
  public readonly source: JsonAgainstHumanity;
  private readonly config: Config.JsonAgainstHumanity;
  private readonly storedSummary: Source.Summary;
  private readonly storedTemplates: Decks.Templates;

  public constructor(
    source: JsonAgainstHumanity,
    config: Config.JsonAgainstHumanity,
    summary: Source.Summary,
    templates: Decks.Templates
  ) {
    super();
    this.source = source;
    this.config = config;
    this.storedSummary = summary;
    this.storedTemplates = templates;
  }

  public id(): string {
    return "JAH";
  }

  public deckId(): string {
    return this.source.id;
  }

  public loadingDetails(): Source.Details {
    return {
      name: this.storedSummary.details.name,
    };
  }

  public equals(source: Source.External): boolean {
    return source.source === "JAH" && this.source.id === source.id;
  }

  public async getTag(): Promise<string | undefined> {
    return (await this.summary()).tag;
  }

  public async atLeastSummary(): Promise<Source.AtLeastSummary> {
    return await this.summaryAndTemplates();
  }

  public async atLeastTemplates(): Promise<Source.AtLeastTemplates> {
    return await this.summaryAndTemplates();
  }

  public summaryAndTemplates = async (): Promise<{
    summary: Source.Summary;
    templates: Decks.Templates;
  }> => ({
    summary: this.storedSummary,
    templates: this.storedTemplates,
  });
}

export class MetaResolver implements Source.MetaResolver<JsonAgainstHumanity> {
  private readonly config: Config.JsonAgainstHumanity;
  private readonly decks: Map<
    string,
    {
      summary: Source.Summary;
      templates: Decks.Templates;
    }
  >;
  private readonly order: string[];
  public readonly cache = false;

  public constructor(config: Config.JsonAgainstHumanity, decks: RawDecks) {
    this.config = config;
    this.decks = new Map();
    const protoOrder: [string, RawDeck][] = [];
    for (const id in decks.decks) {
      this.decks.set(id, rawDeckToSummaryAndTemplates(decks, id));
      protoOrder.push([id, decks.decks[id]]);
    }
    protoOrder.sort(MetaResolver.compare);
    this.order = protoOrder.map(([id, _]) => id);
  }

  private static compare(
    [_idA, a]: [string, RawDeck],
    [_idB, b]: [string, RawDeck]
  ): number {
    const official = MetaResolver.boolCompare(a, b, (v) => v.official);
    if (official !== 0) {
      return official;
    } else {
      const isThirdParty = MetaResolver.boolCompare(a, b, (v) =>
        v.name.startsWith("[$]")
      );
      if (isThirdParty !== 0) {
        return isThirdParty;
      } else {
        const isCommunity = MetaResolver.boolCompare(a, b, (v) =>
          v.name.startsWith("[C]")
        );
        if (isCommunity !== 0) {
          return isCommunity;
        } else {
          return 0;
        }
      }
    }
  }

  private static boolCompare<T>(a: T, b: T, f: (t: T) => boolean): number {
    const x = f(a);
    const y = f(b);
    return x && !y ? -1 : y && !x ? 1 : 0;
  }

  public clientInfo(): ClientInfo {
    return {
      aboutUrl: this.config.aboutUrl,
      decks: this.order.map((id) => ({
        id,
        name: (this.decks.get(id) as { summary: Source.Summary }).summary
          .details.name,
      })),
    };
  }

  limitedResolver(source: JsonAgainstHumanity): Resolver {
    return this.resolver(source);
  }

  resolver(source: JsonAgainstHumanity): Resolver {
    const deck = this.decks.get(source.id);
    if (deck !== undefined) {
      const { summary, templates } = deck;
      return new Resolver(source, this.config, summary, templates);
    } else {
      throw new SourceNotFoundError(source);
    }
  }
}

export const load = async (
  config: Config.JsonAgainstHumanity
): Promise<MetaResolver> => {
  const httpConfig: AxiosRequestConfig = {
    method: "GET",
    baseURL: config.url,
    responseType: "json",
  };

  const data = await http.get("", httpConfig);
  return new MetaResolver(config, data.data);
};

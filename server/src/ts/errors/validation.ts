import HttpStatus from "http-status-codes";
import * as errors from "../errors";

export interface Details extends errors.Details {
  reason: string;
}

export class InvalidActionError extends errors.MassiveDecksError<Details> {
  public readonly status = HttpStatus.BAD_REQUEST;
  public readonly reason: string;

  public constructor(reason: string) {
    super(`Bad request: ${reason}`);
    this.reason = reason;
    Error.captureStackTrace(this, InvalidActionError);
  }

  public details: () => Details = () => ({
    error: "InvalidAction",
    reason: this.reason
  });
}

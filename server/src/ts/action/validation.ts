import { Action as ActionType } from "../action";
import { CreateLobby as CreateLobbyType } from "../action/initial/create-lobby";
import { RegisterUser as RegisterUserType } from "../action/initial/register-user";
import { CheckAlive as CheckAliveType } from "../action/initial/check-alive";

export type Action = ActionType;
export type CreateLobby = CreateLobbyType;
export type RegisterUser = RegisterUserType;
export type CheckAlive = CheckAliveType;

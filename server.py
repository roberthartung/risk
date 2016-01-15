#!/usr/bin/env python

import asyncio
import datetime
import random
import websockets
import json
from enum import Enum;

class GameState(Enum):
    # Game has not started yet, waiting for players to join
    lobby = 0
    # Game is in preparation mode, place troops etc
    preparation = 1
    # Actual game has started
    started = 2
    # Game has finished and is complete
    finished = 3

games = {}
users = {}

class Session:
    def __init__(self, user, game, ws):
        self.user = user
        self.game = game
        self.ws = ws

    def __str__(self):
        return "<Session: "+str(self.user)+"/"+str(self.game)+">"

    async def send(self, s):
        await self.ws.send(s)

    async def sendMessage(self, m):
        await self.send(json.dumps(m))

    async def close(self):
        # remove session from user and game
        await self.user.removeSession(self)

class User:
    sessions = set()
    def __init__(self, name, pw):
        self.name = name
        self.pw = pw

    async def createSession(self, game, ws):
        session = Session(self, game, ws)
        self.sessions.add(session)
        await game.addSession(session)
        return session

    async def removeSession(self, session):
        await session.game.removeSession(session)
        self.sessions.remove(session)

    def __str__(self):
        return "<User: "+self.name+">"

class Game:
    state = GameState.lobby
    sessions = set()
    users = set()
    leader = None
    user_round_iterator = None
    def __init__(self, name):
        self.name = name

    async def sendMessage(self, obj):
        message = json.dumps(obj)
        for session in self.sessions:
            await session.ws.send(message)

    async def checkLeader(self):
        if (self.leader == None):
            try:
                self.leader = next(iter(self.users))
                await self.sendMessage({'type':'LeaderChangedMessage','leader':self.leader.name})
            except:
                print("Unable to determine leader!")
                print("Game empty?")

    # Method for adding a user to the game
    async def addUser(self, user):
        # user can only join if in lobby state, or already in list!
        if (self.state == GameState.lobby):
            # send message to all existing users
            await self.sendMessage({'type':'UserJoinedMessage','user':user.name})
            self.users.add(user)
            return True
        elif (user in self.users):
            return True
        return False

    # Remove user from game
    async def removeUser(self, user):
        # If user is not in this game or state is wrong -> ABORT
        if(not user in self.users) or (self.state != GameState.lobby):
            return False
        # Remove user first, so the message gets only send to the remaining users
        self.users.remove(user)
        await self.sendMessage({'type':'UserQuitMessage','user':user.name})
        if(user == self.leader):
            self.leader = None
            await self.checkLeader()
        return True

    # ...
    async def addSession(self, new_session):
        # send message to all existing user before
        await self.sendMessage({'type':'UserOnlineMessage','user':new_session.user.name})
        # add session
        self.sessions.add(new_session)
        # send list of names to all users!
        list_of_user_names = []
        for user in self.users:
            list_of_user_names.append(user.name)
        await new_session.sendMessage({'type':'ListOfUsersMessage','users':list_of_user_names})

        await self.checkLeader()

        await self.sendMessage({'type': 'GameInformationMessage', 'state': self.state.value, 'leader': self.leader.name, 'you': new_session.user.name})

    # ...
    async def removeSession(self, session):
        self.sessions.remove(session)
        await self.sendMessage({'type':'UserOfflineMessage','user':session.user.name})
        # try to remove user (only when in game lobby)
        await self.removeUser(session.user)

    async def start(self):
        if (self.state != GameState.lobby):
            return False
        await self.startPreparation()
        return True

    async def changeState(self, newState):
        self.state = newState
        await self.sendMessage({'type': 'GameStateChangedMessage', 'state': self.state.value})

    async def startPreparation(self):
        await self.changeState(GameState.preparation)
        await self.roundStep()

    async def roundStep(self):
        if (self.user_round_iterator == None):
            self.user_round_iterator = iter(self.users)

        next_user = None
        try:
            next_user = next(self.user_round_iterator)
        except StopIteration:
            self.user_round_iterator = iter(self.users)
            next_user = next(self.user_round_iterator)
            print("No next user in iterator!")
            pass

        if (self.state == GameState.preparation):
            # check if preparation complete?
            if False:
                # go to next state here!
                pass
            else:
                print("Next User: " + str(next_user))
                for session in next_user.sessions:
                    await session.sendMessage({'type':'NextMoveMessage'})

    def __str__(self):
        return "<Game: "+self.name+">"

# Handler for one websocket connection (browser session)
# Only one login/game is allowed per instance!
async def handler(websocket, path):
    global games
    # User not logged / attached to game!
    session = None
    while True:
        try:
            frame = await websocket.recv()

            obj = json.loads(frame)
            frame_type = obj['type']
            if (frame_type == 'LoginMessage'):
                user_name = obj['name']
                user_pass = obj['pass']
                game_name = obj['game']

                if(session != None):
                    print("Session already established: " + str(session))
                    continue

                # create user if necessary
                if(user_name in users):
                    user = users[user_name]
                else:
                    user = User(user_name, user_pass)
                    users[user_name] = user

                if (user.pw == user_pass):
                    # create game if necessary
                    if(game_name in games):
                        game = games[game_name]
                    else:
                        game = Game(game_name)
                        games[game_name] = game

                    # Try to add user to game!
                    added = await game.addUser(user)
                    if(added):
                        session = await user.createSession(game, websocket)
                        print("Session created " + str(session))
                    else:
                        print("Unable to add user to game!")
            elif (frame_type == 'StartGameMessage'):
                if(session != None):
                    await session.game.start()
            elif (frame_type == 'MoveFinishedMessage'):
                if(session != None):
                    await session.game.roundStep()
            else:
                print("Unknown message received: " + str(obj))
        except websockets.exceptions.ConnectionClosed:
            if (session != None):
                await session.close()
                print("Session closed " + str(session))
            break

start_server = websockets.serve(handler, '0.0.0.0', 5678)

asyncio.get_event_loop().run_until_complete(start_server)
asyncio.get_event_loop().run_forever()

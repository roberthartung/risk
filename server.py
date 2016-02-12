#!/usr/bin/env python

import asyncio
import datetime
import random
import websockets
import json
from enum import Enum
import gamemap
import sys
import copy
import random

mapinfo = gamemap.MapInfo('web/map.svg')
COLORS=['black', 'green', 'yellow', 'red', 'blue', 'cyan', 'orange']

# TODO(rh): Uppercase members
class GameState(Enum):
    # Game has not started yet, waiting for players to join
    lobby = 0
    # Game is in preparation mode, place troops etc
    preparation = 1
    # Actual game has started
    started = 2
    # Game has finished and is complete
    finished = 3

class PreparationPhase(Enum):
    # Conquering the countries
    CONQUER = 0
    # Reinforce
    REINFORCE = 1

class GamePhase(Enum):
    REINFORCE = 0
    ATTACK = 1
    MOVE_ARMY = 2
    DRAW_CARD = 3

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
    #sessions = set()
    def __init__(self, name, pw):
        self.name = name
        self.pw = pw
        self.sessions = set()
        self.countries = set()

    async def createSession(self, game, ws):
        session = Session(self, game, ws)
        # print(str(self) + " createSession")
        self.sessions.add(session)
        await game.addSession(session)
        return session

    async def removeSession(self, session):
        await session.game.removeSession(session)
        self.sessions.remove(session)

    def __str__(self):
        return "<User: "+self.name+">"

class Game:
    def __init__(self, name):
        self.sessions = set()
        self.users = set()
        self.user_colors = dict()
        self.user_remaining = dict()
        self.leader = None
        self.current_user = None
        self.user_round_iterator = None
        self.state = GameState.lobby
        self.game_phase = None
        self.name = name
        self.preparation_phase = None
        self.world = copy.deepcopy(mapinfo.world)

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
            available_color = None
            for color in COLORS:
                if not color in self.user_colors.values():
                    available_color = color
                    break

            if available_color == None:
                print("WARN: No color available for user")
                return False

            self.user_colors[user] = available_color
            # send message to all existing users
            await self.sendMessage({'type':'UserJoinedMessage','user':{'name':user.name,'color':available_color}})
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
        del self.user_colors[user]
        await self.sendMessage({'type':'UserQuitMessage','user':{'name':user.name}})
        if(user == self.leader):
            self.leader = None
            await self.checkLeader()
        return True

    # ...
    async def addSession(self, new_session):
        # send message to all existing user before
        await self.sendMessage({'type':'UserOnlineMessage','user':{'name':new_session.user.name}})
        # add session
        self.sessions.add(new_session)
        # send list of names to all users!
        list_of_users = []
        for user in self.users:
            list_of_users.append({'name':user.name,'color':self.user_colors[user]})
        await new_session.sendMessage({'type':'ListOfUsersMessage','users':list_of_users})
        await self.checkLeader()
        await new_session.sendMessage({'type': 'GameInformationMessage', 'state': self.state.value, 'leader': self.leader.name, 'user': {'name':new_session.user.name,'color': self.user_colors[new_session.user]}})

        if (self.current_user != None) and (self.current_user == new_session.user):
            print("Send move message after login")
            await self.sendMoveMessage()

        if self.state == GameState.preparation:
            # print("In preparation phase... Next User: " + str(self.current_user))
            countries = {}
            for country_id, country in self.world.countries.items():
                countries[country_id] = {'user': None if country.user == None else {'name':country.user.name}, 'army': 0}
            msg = {'type':'CountriesListMessage','countries':countries}
            await new_session.sendMessage(msg)

    # ...
    async def removeSession(self, session):
        self.sessions.remove(session)
        await self.sendMessage({'type':'UserOfflineMessage', 'user': {'name':session.user.name}})
        # try to remove user (only when in game lobby)
        await self.removeUser(session.user)

    async def start(self, conquer_random):
        if (self.state != GameState.lobby):
            return False
        await self.startPreparation(conquer_random)
        return True

    async def changeState(self, newState):
        self.state = newState
        await self.sendMessage({'type': 'GameStateChangedMessage', 'state': self.state.value})

    def startReinforce(self):
        self.preparation_phase = PreparationPhase.REINFORCE
        # force new iterator here!
        self.user_round_iterator = None
        number_of_soldiers = 2 * len(self.world.countries) / len(self.users) # 5 #
        print("Switching to REINFORCE phase, #" + str(number_of_soldiers))
        for user in self.users:
            self.addRemainingArmy(user, number_of_soldiers)

    # Enter preparation state. In this state, there are two phases:
    # - Players can conquer countries, until there are all conquered!
    async def startPreparation(self, conquer_random):
        # copy only list, but not references!

        await self.changeState(GameState.preparation)
        if conquer_random:
            countries = list(self.world.countries.values())
            random.shuffle(countries)
            # TODO(rh): Send message with all countries, instead of a single message!
            for country in countries:
                user = self.determineNextUser()
                country.conquer(user)
                await self.sendMessage({'type':'CountryConqueredMessage', 'country': country.id, 'user': {'name':user.name}})
            self.startReinforce()
        else:
            self.preparation_phase = PreparationPhase.CONQUER
            self.available_countries = copy.copy(self.world.countries)

        await self.roundStep()

    async def sendMoveMessage(self):
        if (self.state == GameState.preparation):
            if self.preparation_phase == PreparationPhase.CONQUER:
                message = {'type':'ConquerMoveMessage'}
            else:
                message = {'type':'ReinforceMoveMessage'}

            for session in self.current_user.sessions:
                await session.sendMessage(message)
        elif self.state == GameState.started:
            # Check old state and determine next state!
            if self.game_phase == None:
                self.game_phase = GamePhase.REINFORCE
                # TODO(rh): Can we use the same message here?
                message = {'type':'ReinforceMoveMessage'}
            elif self.game_phase == GamePhase.REINFORCE:
                self.game_phase = GamePhase.ATTACK
                pass
            elif self.game_phase == GamePhase.ATTACK:
                self.game_phase = GamePhase.MOVE_ARMY
            elif self.game_phase == GamePhase.MOVE_ARMY:

            elif self.game_phase == GamePhase.DRAW_CARD:
                # next user?
                pass


    def determineNextUser(self):
        if (self.user_round_iterator == None):
            self.user_round_iterator = iter(self.users)

        try:
            self.current_user = next(self.user_round_iterator)
        except StopIteration:
            self.user_round_iterator = iter(self.users)
            self.current_user = next(self.user_round_iterator)

        return self.current_user

    # Make the next roundstep!
    async def roundStep(self):
        self.determineNextUser()

        if (self.state == GameState.preparation) and (self.preparation_phase == PreparationPhase.REINFORCE) and (self.user_remaining[self.current_user] == 0):
            print("Reinforcing DONE -> Chaning state to 'started'")
            self.preparation_phase = None
            self.user_round_iterator = None
            self.game_phase = None
            await self.changeState(GameState.started)

        print("roundStep: " + str(self.current_user))
        await self.sendMoveMessage()

    async def reinforceCountry(self, session, country_id):
        if not country_id in self.world.countries:
            print("ERROR,Reinforce: Country not found")
            return None
        country = self.world.countries[country_id]

        # 1. Check if session belongs to user
        if not session.user == country.user:
            print("ERROR,Reinforce: User not matching")
            return None
        # 2. Check if user has army to reinforce
        if self.user_remaining[session.user] <= 0:
            print("ERROR,Reinforce: No army left to reinforce!")
            return None
        self.user_remaining[session.user] -= 1
        # 3. Reinforce Country locally
        country.reinforce()
        # 4. Send message to all users
        await self.sendMessage({'type':'CountryReinforcedMessage', 'country': country_id})
        # 5. Make step
        # WAS: session.game
        await self.roundStep()

    async def conquerCountry(self, session, country_id):
        if country_id in self.available_countries:
            print("Country is available for conquering!")
            country = self.available_countries[country_id]
            country.conquer(session.user)
            del self.available_countries[country_id]
            await self.sendMessage({'type':'CountryConqueredMessage', 'country': country_id, 'user': {'name':session.user.name}})
        else:
            print("Country is not available for conquer?!")

        if len(self.available_countries) == 0:
            self.startReinforce()

        await session.game.roundStep()

    def addRemainingArmy(self, user, amount):
        if user in self.user_remaining:
            self.user_remaining[user] += amount
        else:
            self.user_remaining[user] = amount

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
                    await session.game.start(obj['random'])
            #elif (frame_type == 'MoveFinishedMessage'):
            #    if(session != None):
            #        await session.game.roundStep()
            elif (frame_type == 'ConquerMoveFinishedMessage'):
                if (session != None):
                    await session.game.conquerCountry(session, obj['country'])
            elif (frame_type == 'ReinforceMoveFinishedMessage'):
                if (session != None):
                    await session.game.reinforceCountry(session, obj['country'])
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

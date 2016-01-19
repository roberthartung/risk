from xml.dom.minidom import parse, Element
#impl = getDOMImplementation()

#ns = {'svg': 'http://www.w3.org/2000/svg', 'inkscape': 'http://www.inkscape.org/namespaces/inkscape'}

def getChildrenWithTag(root, tagName):
    return list(filter(lambda node: node.nodeName == tagName, root))

def getChildWithId(root, _id):
    return list(filter(lambda node: node.attributes['id'].value == _id, root))

class World:
    def __init__(self):
        self.continents = []
        self.countries = {}

class Continent:
    def __init__(self, i, title):
        self.id = i
        self.title = title
        self.countries = []

    def __str__(self):
        return self.title

class Country:
    def __init__(self, i, title):
        self.id = i
        self.title = title
        self.user = None
        self.connected = set()

    def __str__(self):
        return self.title

class MapInfo:
    def __init__(self, file_name):
        self.doc = parse(file_name)
        self.root = self.doc.documentElement
        self.world = World()
        children = getChildrenWithTag(self.root.childNodes, 'g')
        self.parseCounties(getChildWithId(children, 'countries')[0])
        self.parseConnections(getChildWithId(children, 'connectors')[0])

    def parseCounties(self, root):
        for continentElement in getChildrenWithTag(root.childNodes, 'g'):
            continent = Continent(continentElement.attributes['id'].value, continentElement.attributes['inkscape:label'].value)
            for countryElement in getChildrenWithTag(continentElement.childNodes, 'g'):
                country_id = countryElement.attributes['id'].value
                country = Country(country_id, countryElement.attributes['inkscape:label'].value)
                self.world.countries[country_id] = country
                continent.countries.append(country)
            self.world.continents.append(continent)

    def parseConnections(self, root):
        for connectorElement in getChildrenWithTag(root.childNodes, 'g'):
            for pathElement in getChildrenWithTag(connectorElement.childNodes, 'path'):
                start = pathElement.attributes['inkscape:connection-start'].value[1:].split("-")[0]
                end = pathElement.attributes['inkscape:connection-end'].value[1:].split("-")[0]
                self.world.countries[start].connected.add(self.world.countries[end])
                self.world.countries[end].connected.add(self.world.countries[start])

from xml.dom.minidom import parse, Element, Node

INPUT="map.svg"
OUTPUT="web/map.svg"

doc = parse(INPUT)
svgroot=doc.getElementsByTagName('svg')[0]
connectorsElement = None
countriesElement = None
for child in svgroot.childNodes:
    if (child.nodeType == Node.ELEMENT_NODE) and (child.nodeName == "g"):
        attrid = child.attributes['id'].value
        if attrid == 'connectors':
            connectorsElement = child
        elif attrid == 'countries':
            countriesElement = child

for continentNode in countriesElement.childNodes:
    if (continentNode.nodeType == Node.ELEMENT_NODE) and (continentNode.nodeName == "g"):
        continentid = continentNode.attributes['id'].value
        # print(continentNode)
        for countryNode in continentNode.childNodes:
            if (countryNode.nodeType == Node.ELEMENT_NODE) and (countryNode.nodeName == "g"):
                countryid = countryNode.attributes['id'].value
                primaryPartNode = None
                offset = None
                for countryPartNode in countryNode.childNodes:
                    if (countryPartNode.nodeType == Node.ELEMENT_NODE) and (countryPartNode.nodeName == "path"):
                        # print(countryPartNode.attributes['id'].value)
                        if primaryPartNode == None:
                            primaryPartNode = countryPartNode
                            coords = primaryPartNode.attributes['d'].value.split(' ')
                            offset = coords[1].split(',')
                            offset[0] = float(offset[0])
                            offset[1] = float(offset[1])
                            countryNode.attributes['transform'] = 'translate('+str(offset[0])+','+str(offset[1])+')'

                        coords = countryPartNode.attributes['d'].value.split(' ')
                        firstCoords = coords[1].split(',')
                        firstCoords[0] = float(firstCoords[0])
                        firstCoords[1] = float(firstCoords[1])
                        coords[1] = str(firstCoords[0]-offset[0])+','+str(firstCoords[1]-offset[1])
                        countryPartNode.attributes['d'] = ' '.join(coords)

                circle=countryNode.getElementsByTagName('circle')[0]
                circle.attributes['cx'] = str(float(circle.attributes['cx'].value)-offset[0])
                circle.attributes['cy'] = str(float(circle.attributes['cy'].value)-offset[1])
                circle.attributes['style'].value += '; stroke: #333; stroke-width: 1; stroke-dasharray: 0 0;'

                text = doc.createElement('text')
                text.appendChild(doc.createTextNode('1337'))
                text.attributes['x'] = circle.attributes['cx'].value
                text.attributes['y'] = circle.attributes['cy'].value
                text.attributes['dy'] = '.3em'
                text.attributes['text-anchor'] = 'middle'
                text.attributes['fill'] = 'white'
                text.attributes['style'] = 'font-size: 11px;'
                #text.attributes['baseline-shift'] =
                countryNode.appendChild(text)
                # <text x="50%" y="50%" text-anchor="middle" stroke="#51c5cf" stroke-width="2px" dy=".3em">Look, I’m centered!Look, I’m centered!</text>


with open(OUTPUT, 'w') as fh:
    fh.write(doc.toxml("UTF-8").decode("utf-8"))
    fh.close()

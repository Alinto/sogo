# we perform no validation
class PHPDeserializer:
    def __init__(self, string):
        self.string = string
        if string is None:
            self.length = 0
        else:
            self.length = len(string)
        self.cursor = 0

    def deserializeInteger(self):
        start = self.cursor

        done = False
        while not done:
            if self.cursor < self.length:
                currentChar = self.string[self.cursor]
                if currentChar.isdigit():
                    self.cursor = self.cursor + 1
                else:
                    done = True
            else:
                done = True

        length = self.cursor - start
        if length > 0:
            dInteger = int(self.string[start:self.cursor])
        else:
            dInteger = 0

        return dInteger

    def deserializeBoolean(self):
        start = self.cursor

        if self.cursor < self.length:
            currentChar = self.string[self.cursor]
            if currentChar == "0":
                dBoolean = False
            else:
                dBoolean = True
            self.cursor = self.cursor + 1
        else:
            dBoolean = None

        return dBoolean

    def deserializeString(self):
        length = self.deserializeInteger()
        start = self.cursor + 2
        end = start+length
        value = self.string[start:end]
        self.cursor = end + 1

        return value

    def deserializeArray(self):
        isHash = False
        max = self.deserializeInteger()
        dArray = [ None ] * max

        self.cursor = self.cursor + 2
        count = 0
        while count < max:
            elementIndex = self.deserialize()
            self.cursor = self.cursor + 1
            element = self.deserialize()
            if isHash:
                if type(elementIndex) == int:
                    elementIndex = "%d" % elementIndex
            else:
                if type(elementIndex) != int:
                    dArray = self._arrayToHash(dArray)
                    isHash = True
            dArray[elementIndex] = element
            self.cursor = self.cursor + 1
            count = count + 1

        if self.string[self.cursor] != "}":
            raise Exception, \
                ("inconsistency detected in serialized string at character %d:\n%s"
                 % (self.cursor, self._exceptionSample()))

        return dArray

    def _exceptionSample(self):
        if self.cursor > 30:
            start = self.cursor - 30
            prefix = "..."
        else:
            start = 0
            prefix = ""
        carret = self.cursor + len(prefix) - start
        length = len(self.string)
        if self.cursor + 30 < length:
            end = self.cursor + 30
            suffix = "..."
        else:
            end = length
            suffix = ""

        sample = self.string[start:end]
        while sample[0] == " ":
            carret = carret - 1
            sample = sample[1:]

        return "%s%s%s\n%s^" % (prefix, sample, suffix, carret * " ")

    def _arrayToHash(self, array):
        dHash = {}
        count = 0
        for element in array:
            dHash["%d" % count] = element
            count = count + 1

        return dHash

    def deserialize(self):
        dObject = None

        if self.string is not None and self.length > 0:
            currentChar = self.string[self.cursor]
            self.cursor = self.cursor + 2
            if currentChar == 'a':
                dObject = self.deserializeArray()
            elif currentChar == 's':
                dObject = self.deserializeString()
            elif currentChar == 'i':
                dObject = self.deserializeInteger()
            elif currentChar == 'b':
                dObject = self.deserializeBoolean()
            elif currentChar == 'N':
                dObject = None

        return dObject

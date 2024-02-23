import pino from "pino";
import { prettyFactory } from "pino-pretty";

const makeFormatter = (logLevels) =>
    prettyFactory({
        customLevels: logLevels,
        /// NOTE: the lables have to be lower case! (pino pretty doesn't recognise them if there are upper case letters)
        /// https://www.npmjs.com/package/colorette#supported-colors - these are available colors
        customColors:
            "fatal:bgRed,error:red,warn:yellow,info:green,udebug:bgBlue,uinfo:bgGreen,uwarn:bgYellow,uerror:bgRed,debug:blue,trace:gray",
    });
const makeStreams = (level, formatter) => [
    // pretty({ sync: true }),
    {
        stream: {
            write(v) {
                console.log(formatter(v));
            },
        },
        level
    },
];

export const makelogger = (level, logLevels) => {
    const formatter = makeFormatter(logLevels);
    return pino(
        {
            level,
        },
        pino.multistream(makeStreams(level, formatter)),
    );
};

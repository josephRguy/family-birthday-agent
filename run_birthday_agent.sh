#!/bin/zsh

# ==============================================================
# run_birthday_agent.sh
# Daily cron script: checks Guy Family Mafia shared calendar for
# birthdays/anniversaries, creates yearly recurring events on
# the primary calendar, and sends creative multi-stage email
# reminders.
# ==============================================================

set -euo pipefail

# ---- Configuration (set via environment variables) ----
SENDER="${SENDER_EMAIL:?Error: SENDER_EMAIL env var not set}"
RECIPIENTS="${FAMILY_EMAILS:?Error: FAMILY_EMAILS env var not set}"
CALENDAR_ID="${FAMILY_CALENDAR_ID:?Error: FAMILY_CALENDAR_ID env var not set}"
TOKEN_DIR="${TOKEN_DIR:-$HOME/.birthday-agent}"
STATE_FILE="$HOME/.birthday_agent_state.json"

# ---- Dependency check ----
for cmd in jq perl curl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Missing dependency: $cmd. Install with: brew install $cmd" >&2
        exit 1
    fi
done

# ----------------------------------------------------------------
# CREATIVE TEMPLATES
# Each array holds 50 items. Placeholders: __PERSON_NAME__, __FULL_DATE__
# Defined with single quotes so placeholders remain literal.
# ----------------------------------------------------------------

POEMS_30D=(
    'The days are counting down, one by one,
A celebration has just begun.
__FULL_DATE__ is drawing near,
A day of joy, laughter, and cheer.
__PERSON_NAME__ special day is in sight —
Get ready to make it warm and bright.'
    'Thirty days from now the cake will be cut,
Party hats on and good times abut.
__PERSON_NAME__ turns another year,
So let us raise a glass of cheer.
Mark the date and save the day,
Hooray, hooray, hip hip hooray!'
    'A month from now the balloons will rise,
Streamers dancing under skies.
__PERSON_NAME__ birthday is on the way,
Let the festivities start today.
Begin to plan the grand surprise,
The joy ahead is in your eyes.'
    'In thirty days a star is born —
Well, actually on that lovely morn.
__PERSON_NAME__ came to be,
So mark your calendars and you will see:
A celebration fit for one so great,
Dont let this special moment wait.'
    'The countdown clock has just begun,
Thirty days until the fun.
__PERSON_NAME__ is getting older,
Wiser too and even bolder.
Prepare the gifts and wrap with care,
Another trip around the sun we share.'
    'Four weeks and change until the day
When __PERSON_NAME__ gets to say:
Bring the cake and light the candles,
Untie the gift bows and the handles.
Its almost time to celebrate,
Dont you dare be running late.'
    'A gentle heads-up thirty days out,
Of what the celebration is about.
__PERSON_NAME__ birthday looms ahead,
So clear your schedule go to bed
Early rested full of cheer,
The big day soon will be here.'
    'Like a gift that waits to be unwrapped,
The day approaches soon it will be tapped.
__PERSON_NAME__ is the guest of honor,
So get the confetti and don a
Smile because the time is nigh,
To celebrate beneath the sky.'
    'Thirty days is not that far
For who you are and whose you are.
__PERSON_NAME__ we celebrate you,
And all the wondrous things you do.
Start the engines warm the band,
The happiest of days is planned.'
    'The calendar pages slowly turn,
Another lesson we all learn.
Time is precious love is true,
__PERSON_NAME__ here is a clue:
Your special day is thirty out,
Lets get ready to sing and shout.'
    'A month-long runway to the main event,
Time well spent and heaven sent.
__PERSON_NAME__ birthday is coming fast,
Memories waiting to be cast.
Start the playlist ice the cake,
The celebration we will make.'
    'Listen closely hear the sound,
Thirty days before the crown
Is placed upon __PERSON_NAME__ head,
Celebrations lie ahead.
Get the banners write a rhyme,
Its almost that special time.'
    'Four weeks of anticipation and glee,
For the day when __PERSON_NAME__ we see
Smiling wide and feeling blessed,
Putting worries all to rest.
Get set go its almost here,
The best time of the calendar year.'
    'Twenty-nine sleeps after tonight
Until the morning when the light
Shines on __PERSON_NAME__ special day,
Happiness will come your way.
So start the count and join the cheer,
The celebration is almost here.'
    'The early bird gets the worm they say,
And you get thirty days to say:
Happy birthday to __PERSON_NAME__ so dear,
Make it magnificent this year.
Plan the party choose the theme,
Make it better than a dream.'
    'Way before the big parade,
The groundwork of the birthday made.
__PERSON_NAME__ deserves the best,
So put your party skills to test.
Thirty days to prep and plan,
Show them what a birthday can.'
    'Like fine wine or aged cheese,
Some things ripen with the breeze.
__PERSON_NAME__ birthday is getting near,
The best time of the calendar year.
Twenty nine more days to go,
Before the candles start to glow.'
    'The early warning system works,
So you can find your party perks.
__PERSON_NAME__ day is on the way,
Celebrate without delay.
Grab a hat and grab a horn,
A special someone will be born.'
    'This is not a drill I say,
__FULL_DATE__ is on its way.
__PERSON_NAME__ will be the queen or king,
Of everything that joy can bring.
Start the engines fire the band,
The happiest day in all the land.'
    'A prelude to the grand affair,
Fill the room with love and care.
__PERSON_NAME__ we speak your name,
A celebration we will frame
In memories that will not fade,
The best foundation we have laid.'
    'Thirty days of preparation sweet,
For the day when all will meet
To celebrate __PERSON_NAME__ in style,
To make the moment all worth while.
Get ready now the time is nigh,
To raise our glasses to the sky.'
    'The calendar is a ticking clock,
And on the day we will unlock
A celebration for __PERSON_NAME__,
A day of joy in the hall of fame.
Twenty nine more sunsets wait,
Then we open heavens gate.'
    'A little notice and a little cheer,
The birthday message crystal clear.
__PERSON_NAME__ day is coming soon,
Underneath the sun and moon.
Start the planning lay the ground,
The best celebration will be found.'
    'Dont blink too fast or you might miss,
The buildup to birthday bliss.
__PERSON_NAME__ turns another page,
Stepping onto a brand new stage.
Thirty days and then we cheer,
For someone we all hold so dear.'
    'Take a breath and count to ten,
Then count to thirty once again.
__PERSON_NAME__ birthday will be here,
Bringing laughter bringing cheer.
The calendar is marked in red,
A joyful day lies straight ahead.'
    'The party planning starts today,
Get the decorations on display.
__PERSON_NAME__ is almost due,
For a birthday bright and new.
Thirty days is all we need,
To plant a joyful happy seed.'
    'A month ahead we raise a toast,
To the person we love most.
__PERSON_NAME__ birthday is on its way,
Celebration day by day.
Get the streamers find a hat,
This day will be where joy is at.'
    'Heads up hearts full this ones for you,
Thirty days till something new.
__PERSON_NAME__ you are the reason,
For celebrating every season.
This birthday will be one to save,
A cherished moment that we crave.'
    'The planets are aligning right,
To make this birthday oh so bright.
__PERSON_NAME__ is at the center,
Of the joy we all will enter.
Thirty days until we say,
Happy birthday hip hooray.'
    'Let the anticipation grow,
Like a flower in a row.
__PERSON_NAME__ birthday will be grand,
The best across the promised land.
Thirty days of hopes and dreams,
Nothing is as it now seems.'
    'The time is right the stage is set,
No need for any more regret.
__PERSON_NAME__ day is coming fast,
A celebration that will last.
Start the music cue the lights,
Birthday joy reaches new heights.'
    'One month out a quick hello,
To let you know its time to go
And get the gifts and plan the fun,
For __PERSON_NAME__ everyone.
The best is yet to come we say,
Starting on their special day.'
    'Warm up your voice and stretch your hands,
Across the celebratory lands.
__PERSON_NAME__ deserves a cheer,
That everyone will want to hear.
Thirty days to get it right,
Make their birthday super bright.'
    'A friendly reminder in your ear,
__FULL_DATE__ is almost here.
__PERSON_NAME__ you are the light,
That makes the whole world warm and bright.
Thirty days of anticipation,
Building toward the celebration.'
    'The cake is not yet in the oven,
But the love is more than proven.
__PERSON_NAME__ birthday is on the way,
Make it the best one to date okay.
Thirty days to make a plan,
Show them what a birthday can.'
    'The early call the friendly nudge,
Dont let this birthday hold a grudge.
__PERSON_NAME__ you are adored,
More than any spoken word.
Thirty days from now we meet,
To lay good fortune at your feet.'
    'Like a train thats left the station,
Headed toward the celebration.
__PERSON_NAME__ birthday is en route,
No time for any silly doubt.
Get on board and join the ride,
Celebration multiplied.'
    'Count the days like precious gems,
Dont forget the diadems.
__PERSON_NAME__ you are the treasure,
Whose birthday we will all measure.
Thirty days of sparkling light,
Leading up to your big night.'
    'A whisper in the cosmic breeze,
Carried on through all the trees.
__PERSON_NAME__ birthday is in sight,
Time to make the day feel right.
Twenty nine more suns to set,
Then the day that we wont forget.'
    'The invitations not yet sent,
But the good intentions have been spent.
__PERSON_NAME__ we hold you dear,
Your birthday is the best all year.
Thirty days to bring the joy,
For our favorite girl or boy.'
    'Think of all the smiles to come,
The laughter from everyone.
__PERSON_NAME__ birthday is the key,
To happiness for you and me.
Thirty days of building bliss,
Building up to that first kiss
Of cake and candles singing loud,
Standing tall and feeling proud.'
    'The countdown has officially started,
With a heart that is warm hearted.
__PERSON_NAME__ you mean the world,
So let the birthday flags be unfurled.
Thirty days of preparation,
Building toward the celebration.'
    'Prepare the confetti get the noise makers,
Were celebrating our earth shakers.
__PERSON_NAME__ birthday is on its way,
Make it magnificent hip hooray.
Thirty days and counting down,
The best celebration in the town.'
    'Do you hear what I hear now?
Birthday whispers start avow.
__PERSON_NAME__ is almost due,
For the spotlight bright and new.
Thirty days to plan prepare,
Show them just how much we care.'
    'The early bird gets the party done,
So when the day comes it is fun.
__PERSON_NAME__ we sing for you,
A melody so fresh and new.
Thirty days until the chorus,
The best day ever is before us.'
    'Mark it down and set a date,
Dont you dare procrastinate.
__PERSON_NAME__ birthday is coming fast,
A celebration that will last.
Twenty nine more nights to sleep,
Then the promises we keep.'
    'A little notice from the heart,
Before the festivities start.
__PERSON_NAME__ you are the reason,
For this happy special season.
Thirty days to get it right,
Make the celebration bright.'
    'The stars are aligning every night,
To make your birthday oh so bright.
__PERSON_NAME__ you are the one,
Who makes this a special sun.
Thirty days of shining light,
Leading to your special night.'
    'Start your engines get in gear,
The birthday message is now clear.
__PERSON_NAME__ we celebrate you,
In everything we say and do.
Thirty days of happy cheer,
The best birthday of the year.'
    'A friendly voice across the wire,
Filled with joy and hearts desire.
__PERSON_NAME__ your day is near,
Filled with laughter and good cheer.
Thirty days of sweet delight,
Leading to your special night.'
)

RIDDLES_7D=(
    'I get bigger when you blow me out.
I stand tall but melt with a shout.
Surrounded by flames yet never on fire,
On __FULL_DATE__ I fulfill desire.
What am I?
(Answer: A birthday candle — and __PERSON_NAME__ is ready to blow them out!)'
    'Wrapped in paper tied with bow,
You never know whats down below.
A surprise waits for __PERSON_NAME__ dear,
Just one week from now it will appear.
What am I?
(Answer: A birthday gift)'
    'I am round and sweet and layers deep,
A secret treasure that we keep.
With every slice a smile appears,
On __FULL_DATE__ it calms all fears.
What am I?
(Answer: A birthday cake — seven days until __PERSON_NAME__ gets a slice!)'
    'I am not a bird but I can fly,
Across the room up to the sky.
I bring color to the air,
At the birthday party fair.
What am I?
(Answer: A balloon — get ready for __PERSON_NAME__ celebration!)'
    'I have a face and two hands too,
But I dont eat or speak to you.
I mark the days and count them all,
Until the birthday party call.
What am I?
(Answer: A clock — ticking down to __PERSON_NAME__ big day!)'
    'I am a number that gets bigger each year,
But those who have me have nothing to fear.
__PERSON_NAME__ is gaining one more,
Seven days and Ill be in store.
What am I?
(Answer: Age — just a number for __PERSON_NAME__!)'
    'I come in a roll and I am full of cheer,
I help you remember the day of the year.
Tear me off day by day,
Until __FULL_DATE__ comes to play.
What am I?
(Answer: A calendar — one week to go!)'
    'I am worn on the head but not a hat,
I point to the year something is at.
Sometimes I am pointed sometimes I am flat,
I help you celebrate this and that.
What am I?
(Answer: A party hat — almost time for __PERSON_NAME__ to wear one!)'
    'I am full of air and tied with string,
I bob in the air at everything.
I come in colors bright and bold,
A birthday story to be told.
What am I?
(Answer: A balloon — seven days until the sky fills with them for __PERSON_NAME__!)'
    'I am sweet and cold and made with cream,
A birthday table dream.
I sit beside the cake and pie,
Winking at the passers by.
What am I?
(Answer: Ice cream — for __PERSON_NAME__ celebration!)'
    'I am a message written with care,
Tucked in an envelope square.
I travel miles to say to you,
That __PERSON_NAME__ is loved and true.
What am I?
(Answer: A birthday card — one week to send yours!)'
    'I am made of metal paper or wax,
I hold the candles in my tracks.
On __FULL_DATE__ I come to life,
Ending all the birthday strife.
What am I?
(Answer: A birthday cake stand)'
    'I go on the wall and not on the floor,
I bring the cheer and sometimes more.
I unfurl with a message bright,
Making __PERSON_NAME__ birthday right.
What am I?
(Answer: A birthday banner — seven days to hang it!)'
    'I am a melody you sing out loud,
To the birthday girl or boy in the crowd.
I start with happy and end with day,
And everyone joins in to say
What am I?
(Answer: The Happy Birthday song — warming up for __PERSON_NAME__!)'
    'I come in a box and I am often square,
You shake and rattle to guess whats there.
Seven days until __PERSON_NAME__ opens me,
Full of love and jubilee.
What am I?
(Answer: A birthday present)'
    'I have a wick but I am not a lamp,
I sit on cakes in a sticky clamp.
I am lit with fire and blown with breath,
Marking the day of life and death.
What am I?
(Answer: A birthday candle — for __PERSON_NAME__ wish!)'
    'I pop and fizz and light the sky,
Catching every gazing eye.
I celebrate with flash and sound,
When __PERSON_NAME__ day comes around.
What am I?
(Answer: A firework — get ready for the show!)'
    'I am a promise wrapped in a bow,
I wait for the right time to show.
Underneath the wrapping paper deep,
A secret that the family will keep.
What am I?
(Answer: A birthday surprise — for __PERSON_NAME__!)'
    'I keep your drinks cold on the day,
When everyone comes to play.
I am filled with ice and soda too,
A birthday classic through and through.
What am I?
(Answer: A cooler — seven days to stock it for __PERSON_NAME__!)'
    'I am made of sugar eggs and flour,
I bake for hours at full power.
When I am done I wear a frosting coat,
Seven days until __PERSON_NAME__ gets a note
That says its time to eat me up.
What am I?
(Answer: A birthday cake baking)'
    'I am a chain of colorful rings,
That everyone loves and everything brings.
I decorate the room with flair,
Hanging ribbons everywhere.
What am I?
(Answer: Streamers — almost time to hang them for __PERSON_NAME__!)'
    'I am small but mighty in the hand,
I help you blow across the land.
When candles flicker I am the source,
Of the gust that changes course.
What am I?
(Answer: Your breath — practice for __PERSON_NAME__ candles!)'
    'I hold a memory of the past,
A snapshot taken fast.
I freeze the smile on __PERSON_NAME__ face,
In the birthday time and space.
What am I?
(Answer: A photograph — ready for __PERSON_NAME__ close-up!)'
    'I am round and flat and covered in wax,
I get passed around for birthday snacks.
I am not the cake but close enough,
The birthday table is my stuff.
What am I?
(Answer: A plate — seven days until they are filled for __PERSON_NAME__!)'
    'I am not a shower but I come in a spray,
I make the birthday mess go away.
I am sweet and scented in the air,
A birthday bathroom affair.
What am I?
(Answer: Air freshener — getting ready for __PERSON_NAME__ guests!)'
    'I am a number printed on a sheet,
I hang on the wall for all to meet.
I count the days of every year,
And on __FULL_DATE__ we cheer.
What am I?
(Answer: A calendar page — one more flip until __PERSON_NAME__ day!)'
    'I am a string of tiny lights,
That make the birthday evenings bright.
I twinkle on and off with grace,
A smile upon __PERSON_NAME__ face.
What am I?
(Answer: Fairy lights — decorating for the birthday!)'
    'I sit on the table and spin around,
With treats and snacks that will astound.
I am a lazy susan full of cheer,
Revolving through the birthday year.
What am I?
(Answer: A Lazy Susan — loaded for __PERSON_NAME__ party!)'
    'I am the guest of honor seat,
The place where joy and happiness meet.
At the head of the table I wait,
For __PERSON_NAME__ who will celebrate.
What am I?
(Answer: The special chair — one week until __PERSON_NAME__ sits here!)'
    'I am made of paper but I hold a song,
The melody carries the whole day long.
I open and close with a happy sound,
Birthday music all around.
What am I?
(Answer: A musical birthday card — on its way for __PERSON_NAME__!)'
    'I am a circle worn on the wrist,
Or on a cake all covered in mist.
I mark the time of year and day,
When __PERSON_NAME__ gets to play.
What am I?
(Answer: A watch or a ring — time to celebrate!)'
    'I have no mouth but I can speak,
Every seven days of the week.
I say that __FULL_DATE__ is on its way,
Only seven more sleeps until the day.
What am I?
(Answer: A clock — counting down for __PERSON_NAME__!)'
    'I am a bag of crinkly fun,
With handles for everyone.
I carry gifts both big and small,
Walking proudly down the hall.
What am I?
(Answer: A gift bag — ready for __PERSON_NAME__ presents!)'
    'I stick to walls and shout out loud,
Look at me I am so proud!
I announce the birthday news,
For everyone to see and choose.
What am I?
(Answer: A poster — announcing __PERSON_NAME__ birthday!)'
    'I am a ribbon curly and bright,
Wrapped around a gift so tight.
I add the finishing touch of grace,
To the smile on __PERSON_NAME__ face.
What am I?
(Answer: A gift ribbon — decorating for __PERSON_NAME__!)'
    'I am a list of things to do,
Before the birthday comes for you.
I keep you on the right track,
So nothing falls through the crack.
What am I?
(Answer: A checklist — seven days to get ready for __PERSON_NAME__!)'
    'I am the space where everyone meets,
With chairs and tables and special treats.
I am filled with joy and fun,
When the celebration has begun.
What am I?
(Answer: The party room — waiting for __PERSON_NAME__!)'
    'I am the song that gets stuck in your head,
Long after the guests have fled.
I repeat and loop and bring you cheer,
Happy birthday to you and you and you here.
What am I?
(Answer: The birthday song — humming it for __PERSON_NAME__!)'
    'I am a wish upon the flame,
A secret whispered without shame.
When candles flicker and die out,
The wish is carried all about.
What am I?
(Answer: A birthday wish — ready for __PERSON_NAME__ to make!)'
    'I am a game of pass the parcel or pin the tail,
Where laughter and joy will prevail.
I bring the fun and the cheer,
When __PERSON_NAME__ birthday is here.
What am I?
(Answer: A party game — one week to plan them!)'
    'I am a cup of colorful stuff,
Filled with pretzels nuts and puff.
I sit beside the birthday spread,
Waiting for the words be said.
What am I?
(Answer: A snack cup — for __PERSON_NAME__ guests!)'
    'I am a notebook or a list,
Where plans are made and then exist.
I hold the thoughts of what to get,
For __PERSON_NAME__ that we bet.
What am I?
(Answer: A planner — organizing __PERSON_NAME__ birthday!)'
    'I am a playlist of favorite tunes,
For dancing under the suns and moons.
I set the mood and the beat,
For celebrating __PERSON_NAME__ feat.
What am I?
(Answer: A party playlist — one week to curate it!)'
    'I am a frame of metal or wood,
Holding memories of the good.
On __FULL_DATE__ I will hold,
A smile worth more than gold.
What am I?
(Answer: A picture frame — ready for __PERSON_NAME__ birthday photo!)'
    'I am a toast of bubbly cheer,
Raised high for all to hear.
I honor __PERSON_NAME__ and the day,
In the most elegant way.
What am I?
(Answer: A champagne flute — one week to polish it!)'
    'I am a napkin folded with art,
Playing a decorative part.
I sit on laps and wipe a smile,
At the birthday party in style.
What am I?
(Answer: A party napkin — stocked for __PERSON_NAME__ celebration!)'
    'I am a tablecloth of paper or lace,
Setting the stage in the birthday space.
I cover the table clean and bright,
Making the party feel just right.
What am I?
(Answer: A tablecloth — laid out for __PERSON_NAME__!)'
    'I am a goodie bag at the end,
Filled with treats that we send.
I thank the guests for coming through,
To celebrate the day with you.
What am I?
(Answer: A party favor bag — ready for __PERSON_NAME__ party!)'
    'I am a candle shaped as a number,
I never slumber in the summer.
I sit on top of the cake with pride,
For __PERSON_NAME__ to blow aside.
What am I?
(Answer: A number candle — marking __PERSON_NAME__ age!)'
    'I am the wish that comes alive,
On the day of the big five.
Or four or six or twenty three,
__PERSON_NAME__ you are the key.
What am I?
(Answer: A birthday celebration — and it is almost here!)'
)

HAIKUS_D=(
    'Happy birthday now,
__PERSON_NAME__ you shine so bright,
Celebrate today.'
    'Candles in the night,
__PERSON_NAME__ makes a wish so bright,
A new year begins.'
    'Balloons touch the sky,
__PERSON_NAME__ gives a happy sigh,
Time to celebrate.'
    'One more trip around,
__PERSON_NAME__ on hallowed ground,
Joy and peace abound.'
    'Party hats go on,
__PERSON_NAME__ the night goes on,
Sing the birthday song.'
    'Sunrise on your day,
__PERSON_NAME__ lights the way,
Happy birthday play.'
    'Friends and family cheer,
__PERSON_NAME__ birthday is here,
Best time of the year.'
    'Cake and candles too,
__PERSON_NAME__ wished on the dew,
Happy birthday you.'
    'Streamers in the air,
__PERSON_NAME__ without a care,
Birthday joy to share.'
    'Another year done,
__PERSON_NAME__ you are the one,
A new race is run.'
    'Smile upon your face,
__PERSON_NAME__ in happy place,
Warm and full of grace.'
    'Gift wrapped with a bow,
__PERSON_NAME__ let the joy flow,
Party time hello.'
    'A moment so sweet,
__PERSON_NAME__ makes the day complete,
Birthday joy repeat.'
    'Fire in the sky,
__PERSON_NAME__ asking why,
Another year gone by.'
    'Music starts to play,
__PERSON_NAME__ birthday today,
Dance the night away.'
    'Starlight in your eyes,
__PERSON_NAME__ under smiling skies,
Time to energize.'
    'Champagne bubbles pop,
__PERSON_NAME__ at the top,
Celebration cant stop.'
    'Balloons float so high,
__PERSON_NAME__ touches the sky,
Birthday wings to fly.'
    'Chocolate and cream,
__PERSON_NAME__ birthday dream,
Nothing is as it seems.'
    'The big day is here,
__PERSON_NAME__ holds the day dear,
Let out a big cheer.'
    'Presents on the floor,
__PERSON_NAME__ wanting more,
Birthday at the door.'
    'Tick tock goes the clock,
__PERSON_NAME__ birthday unlock,
Time to walk the walk.'
    'Sunshine golden bright,
__PERSON_NAME__ fills the light,
Birthday day and night.'
    'One full year gone past,
__PERSON_NAME__ growing fast,
Happy times amassed.'
    'Wait is over now,
__PERSON_NAME__ takes a bow,
Happy birthday wow.'
    'Blue sky birds take flight,
__PERSON_NAME__ day is bright,
Everything feels right.'
    'A new age begun,
__PERSON_NAME__ under the sun,
Celebration won.'
    'Old year fades away,
__PERSON_NAME__ on display,
Happy birthday play.'
    'Memory in the making,
__PERSON_NAME__ heart is shaking,
Birthday day awaking.'
    'Garlands and tinsel bright,
__PERSON_NAME__ in the light,
Birthday day and night.'
    'First breath of the day,
__PERSON_NAME__ on display,
Happy birthday play.'
    'Piñata takes a hit,
__PERSON_NAME__ having a bit,
Birthday joy is lit.'
    'Scent of sweet perfume,
__PERSON_NAME__ in full bloom,
Brightening the room.'
    'Before the night ends,
__PERSON_NAME__ birthday lens,
A message we send.'
    'Smiles from ear to ear,
__PERSON_NAME__ birthday is here,
Lets all give a cheer.'
    'A room full of love,
Blessings from above,
__PERSON_NAME__ we love.'
    'Sparklers in the night,
__PERSON_NAME__ shines so bright,
Everything feels right.'
    'Hug and kiss and cheer,
__PERSON_NAME__ birthday is here,
Best time of the year.'
    'The cake has been cut,
__PERSON_NAME__ happiness at,
A celebration hut.'
    'Tears of happy joy,
__PERSON_NAME__ the years alloy,
Birthday we enjoy.'
    'A brand new chapter,
__PERSON_NAME__ happy laughter,
Happy ever after.'
    'Confetti rains down,
__PERSON_NAME__ wears a crown,
Happiest in town.'
    'Mirror on the wall,
__PERSON_NAME__ best of all,
Birthday standing tall.'
    'Not a single frown,
__PERSON_NAME__ birthday in town,
Standing tall not down.'
    'Shoes off dance around,
__PERSON_NAME__ on the ground,
Happy birthday sound.'
    'Lasers and strobe light,
__PERSON_NAME__ through the night,
Birthday burning bright.'
    'Cake and presents and cheer,
__PERSON_NAME__ birthday is here,
Lets give a big cheer.'
    'Heartbeat fast and true,
__PERSON_NAME__ we love you,
Happy birthday new.'
    'Gather round the table,
__PERSON_NAME__ stable and able,
Birthday joy is full.'
    'The gift of today,
__PERSON_NAME__ in a big way,
Happy birthday play.'
)

ANNIV_7D=(
    'Seven days from now the bells will chime,
For __PERSON_NAME__ love that conquers time.
A promise made and kept so true,
The world is brighter thanks to you.
Get ready to celebrate a love so grand,
Across this happy family land.'
    'One week until the special date,
When __PERSON_NAME__ sealed their fate
With a kiss and a vow so sweet,
Making their union complete.
Time to plan a celebration grand,
For the best couple in the land.'
    'Seven days to go my friend,
The celebration will not end.
__PERSON_NAME__ love is a treasure chest,
Full of moments put to rest
And new ones waiting to be born,
On this happy anniversary morn.'
    'Love like wine gets better with age,
That is why we turn the page
For __PERSON_NAME__ and their devotion,
Like a ship on the ocean.
Seven days until we say,
Happy anniversary hip hooray.'
    'Tick tock goes the clock of love,
Sending blessings from above.
__PERSON_NAME__ in a week will be,
Celebrating history.
A union built on steadfast ground,
Where joy and happiness abound.'
    'A week from now the story continues,
Of __PERSON_NAME__ joy that never diminishes.
A bond of love so strong and deep,
Promises that we all keep.
Raise a glass and make a toast,
To the couple we love the most.'
    'Like a ring that has no end,
__PERSON_NAME__ love will ascend
To heights unknown and dreams untold,
A love story brave and bold.
Seven days until we cheer,
For another happy year.'
    'Countdown to the celebration day,
When __PERSON_NAME__ gets to say
I love you in a special way.
Seven days of sweet suspense,
Building up the eloquence
Of a love that will not fade,
The best foundation we have laid.'
    'In just one week the party starts,
For __PERSON_NAME__ and their hearts.
A journey of a thousand miles,
Marked by love and happy smiles.
Get the flowers pour the wine,
This love story is divine.'
    'Seven sunsets one full week,
Until the moment we all seek.
__PERSON_NAME__ you are the flame,
That keeps the family in the game.
Celebrate your special bond,
The kind of love that goes beyond.'
    'The calendar says it is almost time,
For __PERSON_NAME__ love sublime.
A week of memories to unfold,
A story worth more than gold.
Start the preparations now,
For the couple who took the vow.'
    'A gentle breeze of love is blowing,
The seeds of celebration growing.
__PERSON_NAME__ in seven days,
Will be bathed in love and praise.
Get the bubbles pour the cheer,
Another glorious wedding year.'
    'Seven steps and seven days,
Toward the anniversary phrase
Of happy love to you from us,
Without any need for fuss.
__PERSON_NAME__ you are the light,
That makes the whole world warm and bright.'
    'One week of anticipation sweet,
For the moment when we meet
To celebrate __PERSON_NAME__ love,
A gift from the stars above.
Make it special make it grand,
The best in all the promised land.'
    'The countdown has begun in earnest,
For the love that is the sweetest.
__PERSON_NAME__ in a week or less,
Will be wearing happiness.
The dress the suit the happy tears,
The beauty of these seven years.'
    'Time to dust off the confetti,
Make the celebration ready.
__PERSON_NAME__ love is the reason,
For this happy special season.
One week from today we cheer,
For the best time of the year.'
    'A milestone marker on the road,
Of __PERSON_NAME__ love bestowed.
Seven days until the fun,
Under the golden warming sun.
Prepare the music set the stage,
Celebrate the turning page.'
    'Do you hear the wedding bells,
Echoing from ancient wells?
Just a week from now they ring,
For __PERSON_NAME__ everything.
A love that grows and never dies,
Shining bright before our eyes.'
    'The early notice the advance word,
Of a love that is preferred.
__PERSON_NAME__ in just one week,
Will be at their happiest peak.
Get the cameras set the scene,
Celebrate the love routine.'
    'Seven days of happy thought,
Of the love that __PERSON_NAME__ brought
Into this world and all our lives,
Where love and happiness thrives.
Get ready now to celebrate,
The most wonderful loving fate.'
    'Not just a day but a celebration,
Of __PERSON_NAME__ love foundation.
A week to go and counting fast,
A love designed to last and last.
Polish the rings shine the shoes,
Anniversary wins and news.'
    'The countdown clock is ticking loud,
For the couple who made us proud.
__PERSON_NAME__ in just one week,
Will reach the love they always seek.
A bond of trust and gentle care,
A love beyond compare.'
    'Seven pages on the calendar to turn,
Before the lesson we all learn:
__PERSON_NAME__ love is true and deep,
Promises that we all keep.
Get the gifts and plan the toast,
For the couple we love the most.'
    'A whisper turns into a song,
As the week moves right along.
__PERSON_NAME__ love will be the theme,
Of a celebration like a dream.
Get the sparklers light the night,
Make their anniversary bright.'
    'One full cycle of the moon,
Until the love fest comes to noon.
__PERSON_NAME__ you are the reason,
For the joy in every season.
Celebrate the love you share,
The happiness beyond compare.'
    'Seven more sleeps until the day,
When __PERSON_NAME__ gets to say,
I do all over and again,
The love that will never end.
Mark the date and hold it dear,
Another magnificent loving year.'
    'The forecast calls for love and cheer,
When __PERSON_NAME__ anniversary is here.
One week of clouds and sun,
Until the celebration has begun.
Get the balloons make them float,
Anniversary love note.'
    'In seven days the story retold,
Of __PERSON_NAME__ love so bold.
A tale of two who found their way,
To a happy wedding day.
Celebrate the journey taken,
By a love that is not shaken.'
    'Seven candles on the cake of time,
For __PERSON_NAME__ love sublime.
Each flame a year of happy tears,
A decade conquering all fears.
Start the music cue the band,
The best is yet to come by hand.'
    'A week to go we say hooray,
For __PERSON_NAME__ on their special day.
A partnership of equal grace,
A smile on every face.
Prepare the party heartfelt and true,
For the amazing couple we all knew.'
    'The stars are aligning every night,
For the anniversary shining bright.
__PERSON_NAME__ you are the flame,
That keeps the celebration game.
Seven days of glowing fire,
Building toward the heart desire.'
    'One week of waiting almost done,
For the victory that is won.
__PERSON_NAME__ love is the prize,
Shining bright before our eyes.
Get the bubbly make it pop,
The celebration will not stop.'
    'Seven greetings one for each day,
To help you celebrate the way
__PERSON_NAME__ deserves the best,
A love above the rest.
Each day a step closer to the cheer,
Of the anniversary atmosphere.'
    'A short countdown a little wait,
Before the anniversary date.
__PERSON_NAME__ you have made it far,
A love that sets the highest bar.
Raise a glass and toast the pair,
A love beyond compare.'
    'Like a fine wine waiting to be poured,
__PERSON_NAME__ love is adored.
Seven days until the taste,
Of the memories we embraced.
Celebrate the bond so true,
The love that shines in all you do.'
    'The planets are aligning right,
To make this day a happy sight.
__PERSON_NAME__ in a week or so,
Will feel the love and watch it grow.
A celebration of the heart,
A brand new anniversary start.'
    'Seven days of looking back,
At the happy love track.
__PERSON_NAME__ built a life,
Through the happiness and strife.
Now its time to raise a glass,
To the love that will outlast.'
    'The anniversary train is on its way,
Chugging toward the special day.
__PERSON_NAME__ getting near,
A celebration full of cheer.
All aboard the love express,
Wrapped in joy and happiness.'
    'Count the days like precious gems,
On the anniversary diadems.
__PERSON_NAME__ you are the treasure,
Whose love brings endless pleasure.
Seven days of golden light,
Leading to your special night.'
    'Not long now until the cheer,
For the love that is so dear.
__PERSON_NAME__ you inspire,
With your love and heartfelt fire.
Seven days of sweet delight,
Making the anniversary bright.'
    'A week is just a blink of eye,
For the love that will not die.
__PERSON_NAME__ you are the reason,
For the joy in every season.
Celebrate the love you share,
The happiness beyond compare.'
    'Seven pages left to turn,
Before the anniversary lesson we learn:
__PERSON_NAME__ love is true and deep,
Promises that we all keep.
Get the cameras set the scene,
Celebrate the love routine.'
    'The final countdown is in view,
For the love that grew and grew.
__PERSON_NAME__ seven days from now,
Will be taking another bow.
A round of applause for the happy pair,
The love that fills the family air.'
    'Wrap the gift and pick the flowers,
For the couple with superpowers.
__PERSON_NAME__ love is the best,
Putting hearts to the test.
Seven days until the fun,
Under the golden warming sun.'
    'A little countdown post to share,
For the amazing couple there.
__PERSON_NAME__ in just one week,
Will reach the peak of happy peak.
Get the decorations out,
Celebrate love without doubt.'
    'Seven days of sweet suspense,
Building up the eloquence
Of __PERSON_NAME__ love story,
In all its golden glory.
The best is yet to come we say,
On this happy anniversary day.'
    'The invitations sent by heart,
For the celebration to start.
__PERSON_NAME__ you are the guests,
Of the love that beats all tests.
Seven days until they say,
I love you in a special way.'
    'Like a compass pointing true,
__PERSON_NAME__ love shines through.
Seven days until the north,
Of the love you brought forth.
Celebrate the direction right,
Into the anniversary light.'
    'One week to go across the miles,
To the celebration of smiles.
__PERSON_NAME__ you are the reason,
For this happy special season.
Raise a glass and make a cheer,
For another loving year.'
    'The final stretch is here my friend,
The anniversary will not end.
__PERSON_NAME__ in a week will be,
Celebrating history.
A love that grows and never dies,
Shining bright before our eyes.'
)

ANNIV_D=(
    'Today is the day love won it all,
For __PERSON_NAME__ standing tall.
A promise kept a life well shared,
A beautiful love beyond compared.
Happy anniversary celebrate with glee,
You two are a match made in history.'
    'The day has come the bells ring out,
For __PERSON_NAME__ without a doubt.
A year of love and growth and care,
A bond that nothing can impair.
Happy anniversary to the best,
The couple that surpassed the rest.'
    'Happy anniversary to __PERSON_NAME__ today,
Love and joy along the way.
The journey has been bright and true,
Full of happiness and breakthrough.
Celebrate the love you share,
The happiness beyond compare.'
    'Roses are red violets are blue,
Today is the day for __PERSON_NAME__ who
Built a life of love and trust,
In happiness and fairness just.
Happy anniversary have a ball,
You two are the best of all.'
    'A brand new chapter starts today,
For __PERSON_NAME__ on their way.
Another year of love and light,
Making every moment bright.
Congratulations celebrate with cheer,
For another wonderful loving year.'
    'Today is not just any day,
Its __PERSON_NAME__ special love display.
A moment frozen in the sun,
A beautiful race you both have run.
Happy anniversary shout it loud,
To the couple who make us proud.'
    'The cake the flowers the happy tears,
The beauty of the passing years.
__PERSON_NAME__ we honor you,
For the love that grew and grew.
Happy anniversary raise a glass,
To a love that continues to amass.'
    'On this day so long ago,
__PERSON_NAME__ put on a show
Of love and promise ring and vow,
The same bright words we hear right now.
Happy anniversary you two are great,
A celebration of a happy fate.'
    'Pop the cork and sing the song,
For the couple who belong
Together in a world of two,
A dream that always feels brand new.
Happy anniversary __PERSON_NAME__ dear,
Another magnificent loving year.'
    'Candles glow and smiles beam,
For __PERSON_NAME__ love supreme.
Today marks another turn,
Of the pages that we yearn.
Happy anniversary celebrate with cheer,
For another wonderful loving year.'
    'Here is to love and here is to you,
__PERSON_NAME__ the dream came true.
A life of laughter and of peace,
A love that will never cease.
Happy anniversary celebrate today,
In the very best way.'
    'The day is here the time is now,
For __PERSON_NAME__ to take a bow.
A standing ovation for the pair,
The love that fills the family air.
Happy anniversary enjoy the night,
Take a moment in the light.'
    'Another trip around the sun,
Together for everyone.
__PERSON_NAME__ you are the light,
That keeps the celebration bright.
Happy anniversary have some fun,
Your journey has just begun.'
    'Say it loud and say it clear,
Another spectacular anniversary year.
__PERSON_NAME__ we celebrate you,
In everything you say and do.
Happy anniversary here is to more,
The love that you both have in store.'
    'A toast to love a toast to life,
For __PERSON_NAME__ as man and wife and husband.
A union built on solid ground,
Where happiness and joy abound.
Happy anniversary have a ball,
You two are the best of all.'
    'Two hearts one journey together they stand,
__PERSON_NAME__ across the land.
A story of love and friendship deep,
A promise that we all keep.
Happy anniversary celebrate the day,
In a wonderful loving way.'
    'Dance the waltz of love again,
For __PERSON_NAME__ the best of friends
And lovers too for all these years,
Through happiness and occasional tears.
Happy anniversary enjoy the ride,
With the love who stands by your side.'
    'The mirror of the past reveals,
A love that heals and gently feels.
__PERSON_NAME__ you made it through,
A celebration of me and you.
Happy anniversary shine so bright,
You are the best in the family light.'
    'Champagne bubbles in the glass,
For the love that will not pass.
__PERSON_NAME__ today is yours,
The celebration opens doors.
Happy anniversary to the two,
The love that always shines right through.'
    'A love letter written in the air,
For __PERSON_NAME__ everywhere.
The words are simple true and clear,
Happy anniversary have a great year.
Celebrate the love you share,
The happiness beyond compare.'
    'Today the world stands still a bit,
For __PERSON_NAME__ love and grit.
A partnership of equal might,
A beautiful loving light.
Happy anniversary sing the song,
To the couple who belong.'
    'Throw confetti in the air,
For __PERSON_NAME__ love affair.
A beautiful story of two as one,
A journey of a million suns.
Happy anniversary enjoy the glow,
Let the love and laughter flow.'
    'The cake is cut the wine is poured,
For __PERSON_NAME__ who adored
Each other through the years,
Beyond the happiness and tears.
Happy anniversary celebrate with zest,
You put our hearts to the test.'
    'Tip of the hat and raise the glass,
For __PERSON_NAME__ who surpass
Every expectation of what love can be,
A beautiful shining jubilee.
Happy anniversary to the pair,
The love that fills the family air.'
    'The day of days is finally here,
For __PERSON_NAME__ full of cheer.
A celebration of the bond,
That goes far and far beyond.
Happy anniversary make it grand,
Across the family promised land.'
    'Around the sun another lap,
For __PERSON_NAME__ on the map
Of life and love and growing old,
A story bravely told.
Happy anniversary the best is yet,
A love you will never forget.'
    'A cozy dinner a quiet night,
For __PERSON_NAME__ holding tight.
Or a big party with all the crew,
Whatever you love that is what you should do.
Happy anniversary today is yours,
The love that always opens doors.'
    'In the garden of love and life,
__PERSON_NAME__ without the strife
Bloom eternal ever bright,
Filling darkness with sweet light.
Happy anniversary celebrate the day,
In a wonderful loving way.'
    'Raise the banner hang the sign,
For __PERSON_NAME__ love divine.
Today marks another year,
Of conquering every fear.
Happy anniversary here is to you,
The love that grew and grew.'
    'A journey of a thousand miles,
Marked by __PERSON_NAME__ smiles.
Today we pause to celebrate,
The incredible loving fate.
Happy anniversary you two are blessed,
Above and beyond the rest.'
    'A round of applause for the happy ones,
For __PERSON_NAME__ of the suns.
You light up the room with your love so bright,
Making everything feel right.
Happy anniversary celebrate today,
In the very best way.'
    'Shoes off dancing in the living room,
For __PERSON_NAME__ love in bloom.
Today is yours to hold and keep,
A celebration from the deep.
Happy anniversary enjoy the night,
You two are a beautiful sight.'
    'Gather close and hold on tight,
For __PERSON_NAME__ tonight.
The anniversary of the day,
When love found its way.
Celebrate the bond so true,
The love that shines in all you do.'
    'A day to remember a day to keep,
For __PERSON_NAME__ from the deep
Of our hearts a love so true,
The best that we all ever knew.
Happy anniversary celebrate with cheer,
The best couple of the year.'
    'Photographs and memories made,
For __PERSON_NAME__ the parade
Of love and joy that never ends,
A message that we all send.
Happy anniversary today is grand,
The best in all the promised land.'
    'Here is to the past and the future too,
For __PERSON_NAME__ the dream came true.
Every moment every day,
Love continues to find its way.
Happy anniversary celebrate it big,
Youre a prize worth winning a special cig.'
    'The milestone marker has arrived,
For __PERSON_NAME__ love that thrived.
Through every season change and test,
You are simply the very best.
Happy anniversary enjoy the view,
The world is brighter because of you.'
    'Let the music fill the air,
For __PERSON_NAME__ love affair.
A beat that keeps on playing strong,
A beautiful happy anniversary song.
Dance and sing and laugh and cheer,
For another wonderful loving year.'
    'Not just a day but a celebration,
Of __PERSON_NAME__ love foundation.
Built to last and stand the test,
Above and beyond the rest.
Happy anniversary raise the glass,
For a love that continues to amass.'
    'Two become one and one becomes two,
__PERSON_NAME__ the story grew.
A beautiful tapestry woven with care,
A love beyond compare.
Happy anniversary today is yours,
Open the celebration doors.'
    'The sun rose especially bright today,
For __PERSON_NAME__ on the way
To celebrating the love you share,
The happiness beyond compare.
Happy anniversary shine and glow,
Let the love and laughter flow.'
    'A box of memories open wide,
For __PERSON_NAME__ inside.
Each photo tells a story true,
Of a love that grew and grew.
Happy anniversary take a trip,
Down the memory lane of relationship.'
    'Like the ocean waves on sand,
__PERSON_NAME__ hand in hand.
Gentle strong and ever true,
A love that sees you through.
Happy anniversary celebrate the day,
In a wonderful loving way.'
    'A standing ovation from all of us,
For __PERSON_NAME__ without the fuss.
You make it look so easy and bright,
This whole anniversary light.
Happy anniversary to the pair,
The love that fills the family air.'
    'Confetti streams and party blowers,
For __PERSON_NAME__ the love flows over.
A beautiful celebration of the tie,
That reaches to the sky.
Happy anniversary enjoy the fun,
A magnificent journey.'
    'Pause rewind and celebrate,
For __PERSON_NAME__ and their fate.
A moment frozen in the sun,
A beautiful race you both have run.
Happy anniversary here is to you,
The love that grew and grew.'
    'Here is to the love and here is to the joy,
For __PERSON_NAME__ girl and boy.
A partnership of equal grace,
A smile on every face.
Happy anniversary celebrate grand,
The best couple in the land.'
    'Look back and see how far you came,
For __PERSON_NAME__ calling the name
Of love and trust and happiness,
The best of all we possess.
Happy anniversary have a great time,
You two are truly sublime.'
    'The final chapter of the years,
Turned into happy anniversary tears.
For __PERSON_NAME__ we hold you near,
A message of love so clear.
Congratulations celebrate with might,
Into the warm anniversary night.'
    'One more flower in the bouquet,
Of __PERSON_NAME__ life today.
Each petal a memory soft and dear,
A celebration full of cheer.
Happy anniversary to you both,
The love that everyone knows.'
)

# ---- State File Management ----
init_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        local year
        year=$(date +%Y)
        echo "{\"year\": $year, \"used\": {}}" > "$STATE_FILE"
    fi
}

get_state() {
    init_state
    jq -r "$1 // empty" "$STATE_FILE" 2>/dev/null || echo ""
}

update_state() {
    local event_name="$1"
    local msg_type="$2"
    local idx="$3"

    init_state
    local curr_year
    curr_year=$(date +%Y)
    local state_year
    state_year=$(get_state '.year // 0')

    if [[ "$state_year" != "$curr_year" ]]; then
        echo "{\"year\": $curr_year, \"used\": {}}" > "$STATE_FILE"
    fi

    local key="${event_name}|${msg_type}"
    local current_used
    current_used=$(get_state ".used.\"${key}\" // []")
    if [[ -z "$current_used" || "$current_used" == "null" ]]; then
        current_used="[]"
    fi
    local new_used
    new_used=$(echo "$current_used" | jq --argjson idx "$idx" '. + [$idx]')
    local tmp
    tmp=$(mktemp)
    jq --arg key "$key" --argjson val "$new_used" '.used[$key] = $val' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
}

get_unused_indices() {
    local event_name="$1"
    local msg_type="$2"
    local total="$3"

    init_state
    local curr_year
    curr_year=$(date +%Y)
    local state_year
    state_year=$(get_state '.year // 0')
    if [[ "$state_year" != "$curr_year" ]]; then
        echo "{\"year\": $curr_year, \"used\": {}}" > "$STATE_FILE"
    fi

    local key="${event_name}|${msg_type}"
    local used
    used=$(get_state ".used.\"${key}\" // []")
    if [[ -z "$used" || "$used" == "null" ]]; then
        used="[]"
    fi

    local unused=()
    for (( i=0; i<total; i++ )); do
        if ! echo "$used" | jq -e "index($i)" >/dev/null 2>&1; then
            unused+=("$i")
        fi
    done
    echo "${unused[@]}"
}

# ---- Helper Functions ----
extract_name() {
    local summary="$1"
    local clean="$summary"
    clean=$(echo "$clean" | sed -E 's/\([^)]*\)//g')
    clean=$(echo "$clean" | sed -E 's/[0-9]+(st|nd|rd|th)//g')
    clean=$(echo "$clean" | sed -E 's/[Bb][Ii][Rr][Tt][Hh][Dd][Aa][Yy]//g')
    clean=$(echo "$clean" | sed -E 's/[Aa][Nn][Nn][Ii][Vv][Ee][Rr][Ss][Aa][Rr][Yy]//g')
    clean=$(echo "$clean" | sed -E 's/[Pp][Aa][Rr][Tt][Yy]//g')
    clean=$(echo "$clean" | sed -E 's/[Cc][Ee][Ll][Ee][Bb][Rr][Aa][Tt][Ii][Oo][Nn]//g')
    clean=$(echo "$clean" | sed -E "s/[’']s//g")
    clean=$(echo "$clean" | sed -E "s/^[' \t]+//g; s/[' \t]+$//g")
    clean=$(echo "$clean" | tr -s ' ')
    clean=$(echo "$clean" | xargs)
    if [[ -z "$clean" ]]; then
        echo "$summary"
    else
        echo "$clean"
    fi
}

format_date() {
    local date_str="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        date -jf "%Y-%m-%d" "$date_str" "+%A, %B %-d" 2>/dev/null || echo "$date_str"
    else
        date -d "$date_str" "+%A, %B %-d" 2>/dev/null || echo "$date_str"
    fi
}

# ---- Template Selectors ----
select_unused_template() {
    local array_name="$1"
    local event_name="$2"
    local msg_type="$3"

    eval "local total=\${#${array_name}[@]}"
    local unused_list
    unused_list=($(get_unused_indices "$event_name" "$msg_type" "$total"))

    local idx
    if [[ ${#unused_list[@]} -eq 0 ]]; then
        idx=$(( RANDOM % total ))
    else
        local r=$(( RANDOM % ${#unused_list[@]} ))
        idx=${unused_list[$r]}
    fi

    update_state "$event_name" "$msg_type" "$idx"

    eval "local template=\"\${${array_name}[$idx]}\""
    echo "$template"
}

select_poem() {
    local person_name="$1"
    local full_date="$2"
    local t
    t=$(select_unused_template "POEMS_30D" "$person_name" "poem")
    # shellcheck disable=SC2001
    t=$(echo "$t" | sed -e "s/__PERSON_NAME__/$person_name/g" -e "s/__FULL_DATE__/$full_date/g")
    echo "$t"
}

select_riddle() {
    local person_name="$1"
    local full_date="$2"
    local t
    t=$(select_unused_template "RIDDLES_7D" "$person_name" "riddle")
    t=$(echo "$t" | sed -e "s/__PERSON_NAME__/$person_name/g" -e "s/__FULL_DATE__/$full_date/g")
    echo "$t"
}

select_haiku() {
    local person_name="$1"
    local full_date="$2"
    local t
    t=$(select_unused_template "HAIKUS_D" "$person_name" "haiku")
    t=$(echo "$t" | sed -e "s/__PERSON_NAME__/$person_name/g" -e "s/__FULL_DATE__/$full_date/g")
    echo "$t"
}

select_anniv_7d_message() {
    local person_name="$1"
    local full_date="$2"
    local t
    t=$(select_unused_template "ANNIV_7D" "$person_name" "anniv_7d")
    t=$(echo "$t" | sed -e "s/__PERSON_NAME__/$person_name/g" -e "s/__FULL_DATE__/$full_date/g")
    echo "$t"
}

select_anniv_day_message() {
    local person_name="$1"
    local full_date="$2"
    local t
    t=$(select_unused_template "ANNIV_D" "$person_name" "anniv_day")
    t=$(echo "$t" | sed -e "s/__PERSON_NAME__/$person_name/g" -e "s/__FULL_DATE__/$full_date/g")
    echo "$t"
}

# ---- Email Sending ----
send_reminder_email() {
    local subject="$1"
    local body="$2"

    RAW_EMAIL=$(printf "Content-Type: text/plain; charset=\"UTF-8\"\nFrom: %s\nTo: %s\nSubject: %s\n\n%s" \
        "$SENDER" "$RECIPIENTS" "$subject" "$body")

    local encoded
    encoded=$(echo -n "$RAW_EMAIL" | base64 -w0 | tr '+/' '-_' | tr -d '=\n')

    curl -s -X POST \
        "https://gmail.googleapis.com/gmail/v1/users/me/messages/send" \
        -H "Authorization: Bearer $(cat "$TOKEN_DIR/token.json" | jq -r '.access_token')" \
        -H "Content-Type: application/json" \
        -d "{\"raw\": \"$encoded\"}"
}

# ---- Main ----
main() {
    if [[ ! -f "$TOKEN_DIR/token.json" ]]; then
        echo "No token.json found. Run the initial OAuth setup first." >&2
        exit 1
    fi

    local access_token
    access_token=$(jq -r '.access_token' "$TOKEN_DIR/token.json")

    local expiry
    expiry=$(jq -r '.expiry // 0' "$TOKEN_DIR/token.json" 2>/dev/null)
    local now
    now=$(date +%s)
    if [[ "$expiry" -lt "$now" ]]; then
        echo "Token expired. Refreshing..."
        local refresh_token
        refresh_token=$(jq -r '.refresh_token' "$TOKEN_DIR/token.json")
        local new_token
        new_token=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
            -d "client_id=$(jq -r '.installed.client_id' "$TOKEN_DIR/client_secret.json")" \
            -d "client_secret=$(jq -r '.installed.client_secret' "$TOKEN_DIR/client_secret.json")" \
            -d "refresh_token=$refresh_token" \
            -d "grant_type=refresh_token")
        local new_access
        new_access=$(echo "$new_token" | jq -r '.access_token')
        local new_expiry
        new_expiry=$(( now + $(echo "$new_token" | jq -r '.expires_in // 3600') ))

        jq --arg at "$new_access" --argjson exp "$new_expiry" '.access_token = $at | .expiry = $exp' "$TOKEN_DIR/token.json" > "${TOKEN_DIR}/token_new.json" && mv "${TOKEN_DIR}/token_new.json" "$TOKEN_DIR/token.json"
        access_token="$new_access"
    fi

    local today
    today=$(date +%Y-%m-%d)
    local current_year
    current_year=$(date +%Y)

    local events
    events=$(curl -s \
        "https://www.googleapis.com/calendar/v3/calendars/${CALENDAR_ID}/events?timeMin=${today}T00:00:00Z&timeMax=${today}T23:59:59Z&singleEvents=true&orderBy=startTime" \
        -H "Authorization: Bearer $access_token")

    local matched_events
    matched_events=$(echo "$events" | jq -c '.items[] | select(.summary | test("[Bb][Ii][Rr][Tt][Hh][Dd][Aa][Yy]") or test("[Aa][Nn][Nn][Ii][Vv][Ee][Rr][Ss][Aa][Rr][Yy]"))' 2>/dev/null || true)

    if [[ -z "$matched_events" ]]; then
        local future_events
        future_events=$(curl -s \
            "https://www.googleapis.com/calendar/v3/calendars/${CALENDAR_ID}/events?timeMin=${today}T00:00:00Z&timeMax=$(date -j -v+60d +%Y-%m-%d)T23:59:59Z&singleEvents=true&orderBy=startTime" \
            -H "Authorization: Bearer $access_token")

        local future_matched
        future_matched=$(echo "$future_events" | jq -c '.items[] | select(.summary | test("[Bb][Ii][Rr][Tt][Hh][Dd][Aa][Yy]") or test("[Aa][Nn][Nn][Ii][Vv][Ee][Rr][Ss][Aa][Rr][Yy]"))' 2>/dev/null || true)

        if [[ -z "$future_matched" ]]; then
            echo "No birthdays or anniversaries in the next 60 days."
            exit 0
        fi

        echo "$future_matched" | while IFS= read -r item; do
            local summary
            summary=$(echo "$item" | jq -r '.summary // "Unknown"')
            local event_date
            event_date=$(echo "$item" | jq -r '.start.date // .start.dateTime // ""' | cut -d'T' -f1)
            if [[ -z "$event_date" ]]; then continue; fi

            local person_name
            person_name=$(extract_name "$summary")
            local full_date
            full_date=$(format_date "$event_date")

            local event_epoch
            if [[ "$(uname)" == "Darwin" ]]; then
                event_epoch=$(date -jf "%Y-%m-%d" "$event_date" "+%s" 2>/dev/null || echo 0)
            else
                event_epoch=$(date -d "$event_date" "+%s" 2>/dev/null || echo 0)
            fi
            local today_epoch
            today_epoch=$(date +%s)
            local days_until
            days_until=$(( (event_epoch - today_epoch) / 86400 ))

            if [[ "$summary" =~ [Bb][Ii][Rr][Tt][Hh][Dd][Aa][Yy] ]]; then
                if [[ "$days_until" -eq 30 ]]; then
                    echo "30 days until $person_name birthday. Sending poem reminder..."

                    local poem
                    poem=$(select_poem "$person_name" "$full_date")

                    body="Hello there,

${poem}

🎂 Birthdays are nature's way of telling us to eat more cake!
📅 The Family Timekeeper"

                    send_reminder_email "Mark Your Calendar: Only 30 Days Until ${person_name}'s Birthday!" "$body"
                    echo "Sent 30-day poem for $person_name."

                elif [[ "$days_until" -eq 7 ]]; then
                    echo "7 days until $person_name birthday. Sending riddle reminder..."

                    local riddle
                    riddle=$(select_riddle "$person_name" "$full_date")

                    body="Hola,

${riddle}

⏰ Time's ticking! One week to go — don't be late to the party!
🎁 The Family Timekeeper"

                    send_reminder_email "Just One Week to Go: ${person_name}'s Birthday Is Almost Here!" "$body"
                    echo "Sent 7-day riddle for $person_name."

                elif [[ "$days_until" -eq 0 ]]; then
                    echo "Today is $person_name birthday! Sending haiku..."

                    local haiku
                    haiku=$(select_haiku "$person_name" "$full_date")

                    body="Hi everyone,

${haiku}

Happy birthday, ${person_name}! Hope today is filled with love, laughter, and at least one good surprise.

🎉 Don't count the candles — enjoy the glow!
🕯️ The Family Timekeeper"

                    send_reminder_email "It's Today! Happy Birthday to ${person_name}!" "$body"
                    echo "Sent day-of haiku for $person_name."
                fi

            elif [[ "$summary" =~ [Aa][Nn][Nn][Ii][Vv][Ee][Rr][Ss][Aa][Rr][Yy] ]]; then
                if [[ "$days_until" -eq 7 ]]; then
                    echo "7 days until $person_name anniversary. Sending reminder..."

                    local anniv_msg
                    anniv_msg=$(select_anniv_7d_message "$person_name" "$full_date")

                    body="Hello there,

${anniv_msg}

💍 Love is sharing your last slice of pizza. Happy anniversary to ${person_name}!
🗓️ The Family Timekeeper"

                    send_reminder_email "One Week to Go: ${person_name}'s Anniversary Is Almost Here!" "$body"
                    echo "Sent 7-day anniversary reminder for $person_name."

                elif [[ "$days_until" -eq 0 ]]; then
                    echo "Today is $person_name anniversary! Sending day-of message..."

                    local anniv_day_msg
                    anniv_day_msg=$(select_anniv_day_message "$person_name" "$full_date")

                    body="Hi everyone,

${anniv_day_msg}

🥂 Here's to love, laughter, and happily ever after!
💞 Cheers to ${person_name} from The Family Timekeeper"

                    send_reminder_email "It's Today! Happy Anniversary to ${person_name}!" "$body"
                    echo "Sent day-of anniversary message for $person_name."
                fi
            fi
        done

    else
        # There is an event today
        echo "$matched_events" | while IFS= read -r item; do
            local summary
            summary=$(echo "$item" | jq -r '.summary // "Unknown"')
            local person_name
            person_name=$(extract_name "$summary")
            local event_date
            event_date=$(echo "$item" | jq -r '.start.date // .start.dateTime // ""' | cut -d'T' -f1)
            local full_date
            full_date=$(format_date "$event_date")

            if [[ "$summary" =~ [Bb][Ii][Rr][Tt][Hh][Dd][Aa][Yy] ]]; then
                echo "Today is $person_name birthday! Sending day-of haiku..."

                local haiku
                haiku=$(select_haiku "$person_name" "$full_date")

                body="Hi everyone,

${haiku}

Happy birthday, ${person_name}! Hope today is filled with love, laughter, and at least one good surprise.

🎉 Don't count the candles — enjoy the glow!
🕯️ The Family Timekeeper"

                send_reminder_email "It's Today! Happy Birthday to ${person_name}!" "$body"
                echo "Sent day-of haiku for $person_name."

                # Create yearly recurring event on primary calendar
                local primary_calendar="primary"
                local existing
                existing=$(curl -s \
                    "https://www.googleapis.com/calendar/v3/calendars/${primary_calendar}/events?q=${person_name}+birthday&timeMin=${current_year}-01-01T00:00:00Z&timeMax=${current_year}-12-31T23:59:59Z" \
                    -H "Authorization: Bearer $access_token")

                if ! echo "$existing" | jq -e '.items | length > 0' >/dev/null 2>&1; then
                    local recurring_event
                    recurring_event=$(jq -n \
                        --arg summary "${person_name}'s Birthday" \
                        --arg date "$event_date" \
                        '{
                            summary: $summary,
                            start: { date: $date },
                            end: { date: $date },
                            recurrence: ["RRULE:FREQ=YEARLY"],
                            visibility: "private"
                        }')
                    curl -s -X POST \
                        "https://www.googleapis.com/calendar/v3/calendars/${primary_calendar}/events" \
                        -H "Authorization: Bearer $access_token" \
                        -H "Content-Type: application/json" \
                        -d "$recurring_event" >/dev/null
                    echo "Created yearly recurring event for $person_name birthday on primary calendar."
                fi

            elif [[ "$summary" =~ [Aa][Nn][Nn][Ii][Vv][Ee][Rr][Ss][Aa][Rr][Yy] ]]; then
                echo "Today is $person_name anniversary! Sending day-of message..."

                local anniv_day_msg
                anniv_day_msg=$(select_anniv_day_message "$person_name" "$full_date")

                body="Hi everyone,

${anniv_day_msg}

🥂 Here's to love, laughter, and happily ever after!
💞 Cheers to ${person_name} from The Family Timekeeper"

                send_reminder_email "It's Today! Happy Anniversary to ${person_name}!" "$body"
                echo "Sent day-of anniversary message for $person_name."

                # Create yearly recurring event on primary calendar
                local primary_calendar="primary"
                local existing
                existing=$(curl -s \
                    "https://www.googleapis.com/calendar/v3/calendars/${primary_calendar}/events?q=${person_name}+anniversary&timeMin=${current_year}-01-01T00:00:00Z&timeMax=${current_year}-12-31T23:59:59Z" \
                    -H "Authorization: Bearer $access_token")

                if ! echo "$existing" | jq -e '.items | length > 0' >/dev/null 2>&1; then
                    local recurring_event
                    recurring_event=$(jq -n \
                        --arg summary "${person_name}'s Anniversary" \
                        --arg date "$event_date" \
                        '{
                            summary: $summary,
                            start: { date: $date },
                            end: { date: $date },
                            recurrence: ["RRULE:FREQ=YEARLY"],
                            visibility: "private"
                        }')
                    curl -s -X POST \
                        "https://www.googleapis.com/calendar/v3/calendars/${primary_calendar}/events" \
                        -H "Authorization: Bearer $access_token" \
                        -H "Content-Type: application/json" \
                        -d "$recurring_event" >/dev/null
                    echo "Created yearly recurring event for $person_name anniversary on primary calendar."
                fi
            fi
        done
    fi

    echo "Birthday agent run complete at $(date)."
}

main "$@"

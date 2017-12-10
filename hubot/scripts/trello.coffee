# Description:
#  Trello Task Remind

cronJob = require('cron').CronJob
Trello = require('node-trello')
moment = require('moment')

module.exports = (robot) ->
  ORG = process.env.HUBOT_TRELLO_ORGANIZATION
  MEMBERS = []
  trello = new Trello(
    process.env.HUBOT_TRELLO_KEY,
    process.env.HUBOT_TRELLO_TOKEN
  )

  REGEXP_START_DATE = /\[([^\]]*)\]/

  getOrganizationsMembers = ->
    url = "/1/organizations/#{ORG}/members"
    trello.get url, (err, data) =>
      if err
        return
      MEMBERS = data

  getMemberNameByID = (id) ->
    for member in MEMBERS
      if member.id is id
        return member.username
    return 'channel'

  createMsg1 = (card, due) ->
    member = getMemberNameByID(card.idMembers[0])
    msg = ""
    if member?
      msg += "@" + member + " "
    msg += "タスク警察や！" + "\n"
    msg += "「" + card.name + "」は今日の " + due.format("H:mm") + " が期限やで！\n"
    msg += card.shortUrl + "\n"
    return msg

  createMsg2 = (card, due) ->
    member = getMemberNameByID(card.idMembers[0])
    msg = ""
    if member?
      msg += "@" + member + " "
    msg += "タスク警察や！" + "\n"
    msg += "「" + card.name + "」はあと1時間で期限の " + due.format("H:mm") + " やで！\n"
    msg += card.shortUrl + "\n"
    return msg

  createMsg3 = (card, due) ->
    member = getMemberNameByID(card.idMembers[0])
    msg = ""
    if member?
      msg += "@" + member + " "
    msg += "タスク警察や！" + "\n"
    msg += "「" + card.name + "」が期限の " + due.format("YYYY/MM/DD H:mm") + " を超えとるで！\n"
    msg += card.shortUrl + "\n"
    return msg

  createMsg4 = (card, start) ->
    member = getMemberNameByID(card.idMembers[0])
    msg = ""
    if member?
      msg += "@" + member + " "
    msg += "タスク警察や！" + "\n"
    msg += "「" + card.name.replace(REGEXP_START_DATE, "") + "」は今日 " + start.format("H:mm") + " からスタートやで！\n"
    msg += card.shortUrl + "\n"
    return msg

  createMsg5 = (card, due) ->
    member = getMemberNameByID(card.idMembers[0])
    msg = ""
    if member?
      msg += "@" + member + " "
    msg += "タスク警察や！" + "\n"
    msg += "「" + card.name + "」は明日の " + due.format("H:mm") + " が期限やで！\n"
    msg += card.shortUrl + "\n"
    return msg

  getOrganizationsMembers()

  cronJobDaily = new cronJob("0 0 9 * * *", () ->
    now = moment()
    envelope = room: process.env.HUBOT_SLACK_CHANNEL

    trello.get "/1/boards/#{process.env.HUBOT_TRELLO_BOARD_ID}/cards/open", {}, (err, data) ->
      if err
        robot.send(err)
        return
      # 開始日の9:00
      for card in data
        start = card.name.match REGEXP_START_DATE
        if start?
          start = moment(start[1])
          diff = now.diff(start, 'days')
          if diff == 0
            msg = createMsg4(card, start)
            robot.send envelope, msg

      # 期限日の9:00
      for card in data
        if !(card.due ==null)
          due = moment(card.due)
          diff = now.diff(due, 'days')
          if diff == 0
            msg = createMsg1(card, due)
            robot.send(envelope, msg)
          if diff == 1
            msg = createMsg5(card, due)
            robot.send(envelope, msg)        
  )
  cronJobDaily.start()

  cronJobHourly = new cronJob("0 0 * * * *", () ->
    now = moment()
    envelope = room: process.env.HUBOT_SLACK_CHANNEL

    trello.get "/1/boards/#{process.env.HUBOT_TRELLO_BOARD_ID}/cards/open", {}, (err, data) ->
      if err
        robot.send(err)
        return
      
      # 期限日の1時間前
      for card in data
        if !(card.due ==null)
          due = moment(card.due)
          diffDays = now.diff(due, 'days')
          if diffDays == 0
            diffHours = now.diff(due, 'minutes')
            if diffHours >= -60 and diffHours <=0
              msg = createMsg2(card, due)
              robot.send(envelope, msg)

      # 期限超過
      for card in data
        if !(card.due == null)
          due = moment(card.due)
          diff = now.diff(due, 'minutes')

          if diff >= 0
            msg = createMsg3(card, due)
            robot.send(envelope, msg)
  )
  cronJobHourly.start()
class DaysController < ApplicationController
  before_action :hide_everyday_activities, only: [:edit, :new]

  require 'net/https'
  require 'open-uri'

  def index

  end

  def show
    @day = Day.find(params[:id])
    @cohort = @day.cohort
    @users = @cohort.users

  end


  def new
    @cohort = current_user.cohorts.find(params[:cohort_id])
    @day = @cohort.days.new
  end

  def edit
    @cohort = current_user.cohorts.find(params[:cohort_id])
    @day = @cohort.days.find(params[:id])
  end

  def create
    @cohort = Cohort.find(params[:cohort_id])
    @day = @cohort.days.new(day_params)
    @day.city_id = @cohort.city.id

    if @day.save!
      @day.update_attributes(week_number: @day.name.cweek)
      @day.activities << Activity.where(everyday: true)
      Group.create_everyday_groups(@day)
      redirect_to @cohort, notice: 'Day Created.'
    else
      render @cohort, notice: 'oooops.'
    end
  end

  def update
    @cohort = current_user.cohorts.find(params[:cohort_id])
    @day = @cohort.days.find(params[:id])

    if @day.update(day_params)
      redirect_to @cohort
    else
      redirect_to edit_cohort_day_path(@cohort, @day)
    end
  end

  def destroy
    @cohort = current_user.cohorts.find(params[:cohort_id])

    @cohort.days.find(params[:id]).destroy
    redirect_to cohort_path(@cohort), notice: "Demoed!"
  end

  def add_student_to_group
    @group = Group.find(params[:group_id])
    @student = Student.find(params[:student_id])
    @group.students << @student unless @group.students.include?(@student)
    head :no_content
  end

  def remove_student_from_group
    @group = Group.find(params[:group_id])
    @student = Student.find(params[:student_id])

    @group.students.delete(@student)

  end

  def slack_post

    @day = Day.find(params[:day_id])
    @students = @day.cohort.students.where('slack_username is not null')
    @groups = @day.groups

    @students.all.each do |student|

      stu_groups = @groups.joins(:students).where('students.id = ?', student.id)

      stu_groups_array = []
      stu_groups.order(:start_time).each do |groupinfo|
        the_group = "- #{groupinfo.start_time. strftime('%I:%M')} | #{groupinfo.campus_area.name} | #{groupinfo.users.map(&:name).to_sentence} | #{groupinfo.activities.map(&:name).to_sentence}"
        stu_groups_array << the_group
      end

      token = ENV['slack_token']
      channel = "@#{student.slack_username}"
      text = "Good Morning!
  Here's your schedule for #{@day.name.strftime('%a, %e %b %Y')}:

  #{stu_groups_array.join("\n")}"

      Slack.configure do |config|
        config.token = token
      end

      client = Slack::Web::Client.new
      client.auth_test

      client.chat_postMessage(channel: channel, text: text, as_user: true)

    end

    @day.update_attributes(slack_sent: true)

    redirect_to cohort_day_path(@day.cohort, @day)

  end



  private

  def day_params
    params.require(:day).permit(:name, activity_ids: [])
  end

  def hide_everyday_activities
    @activities = Activity.where(everyday: false).order(:name)
  end
end

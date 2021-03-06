require 'rails_helper'

feature 'Admin polls' do

  background do
    admin = create(:administrator)
    login_as(admin.user)
  end

  scenario 'Index empty', :js do
    visit admin_root_path

    click_link "Polls"
    within('#polls_menu') do
      click_link "Polls"
    end

    expect(page).to have_content "There are no polls"
  end

  scenario 'Index', :js do
    3.times { create(:poll) }

    visit admin_root_path

    click_link "Polls"
    within('#polls_menu') do
      click_link "Polls"
    end

    expect(page).to have_css ".poll", count: 3

    polls = Poll.all
    polls.each do |poll|
      within("#poll_#{poll.id}") do
        expect(page).to have_content poll.name
      end
    end
    expect(page).to_not have_content "There are no polls"
  end

  scenario 'Show' do
    poll = create(:poll)

    visit admin_polls_path
    click_link poll.name

    expect(page).to have_content poll.name
  end

  scenario "Create" do
    visit admin_polls_path
    click_link "Create poll"

    start_date = 1.week.from_now
    end_date = 2.weeks.from_now

    fill_in "poll_name", with: "Upcoming poll"
    fill_in 'poll_starts_at', with: start_date.strftime("%d/%m/%Y")
    fill_in 'poll_ends_at', with: end_date.strftime("%d/%m/%Y")
    click_button "Create poll"

    expect(page).to have_content "Poll created successfully"
    expect(page).to have_content "Upcoming poll"
    expect(page).to have_content I18n.l(start_date.to_date)
    expect(page).to have_content I18n.l(end_date.to_date)
  end

  scenario "Edit" do
    poll = create(:poll)

    visit admin_poll_path(poll)
    click_link "Edit"

    end_date = 1.year.from_now

    fill_in "poll_name", with: "Next Poll"
    fill_in 'poll_ends_at', with: end_date.strftime("%d/%m/%Y")
    click_button "Update poll"

    expect(page).to have_content "Poll updated successfully"
    expect(page).to have_content "Next Poll"
    expect(page).to have_content I18n.l(end_date.to_date)
  end

  scenario 'Edit from index' do
    poll = create(:poll)
    visit admin_polls_path

    within("#poll_#{poll.id}") do
      click_link "Edit"
    end

    expect(current_path).to eq(edit_admin_poll_path(poll))
  end

  context "Booths" do

    context "Poll show" do

      scenario "No booths" do
        poll = create(:poll)
        visit admin_poll_path(poll)
        click_link "Booths (0)"

        expect(page).to have_content "There are no booths assigned to this poll."
      end

      scenario "Booth list" do
        poll = create(:poll)
        3.times { create(:poll_booth, polls: [poll]) }

        visit admin_poll_path(poll)
        click_link "Booths (3)"

        expect(page).to have_css ".booth", count: 3

        poll.booth_assignments.each do |ba|
          within("#poll_booth_assignment_#{ba.id}") do
            expect(page).to have_content ba.booth.name
            expect(page).to have_content ba.booth.location
          end
        end
        expect(page).to_not have_content "There are no booths assigned to this poll."
      end
    end
  end

  context "Officers" do

    context "Poll show" do

      scenario "No officers", :js do
        poll = create(:poll)
        visit admin_poll_path(poll)
        click_link "Officers (0)"

        expect(page).to have_content "There are no officers assigned to this poll"
      end

      scenario "Officer list", :js do
        poll = create(:poll)
        booth = create(:poll_booth, polls: [poll])

        booth.booth_assignments.each do |booth_assignment|
          3.times {create(:poll_officer_assignment, booth_assignment: booth_assignment) }
        end

        visit admin_poll_path(poll)

        click_link "Officers (3)"

        expect(page).to have_css ".officer", count: 3

        officers = Poll::Officer.all
        officers.each do |officer|
          within("#officer_#{officer.id}") do
            expect(page).to have_content officer.name
            expect(page).to have_content officer.email
          end
        end
        expect(page).to_not have_content "There are no officers assigned to this poll"
      end
    end
  end

  context "Questions" do

    context "Poll show" do

      scenario "Question list", :js do
        poll = create(:poll)
        question = create(:poll_question, poll: poll)
        other_question = create(:poll_question)

        visit admin_poll_path(poll)

        expect(page).to have_content "Questions (1)"
        expect(page).to have_content question.title
        expect(page).to_not have_content other_question.title
        expect(page).to_not have_content "There are no questions assigned to this poll"
      end

      scenario 'Add question to poll', :js do
        poll = create(:poll)
        question = create(:poll_question, poll: nil, title: 'Should we rebuild the city?')

        visit admin_poll_path(poll)

        expect(page).to have_content 'Questions (0)'
        expect(page).to have_content 'There are no questions assigned to this poll'

        fill_in 'search-questions', with: 'rebuild'
        click_button 'Search'

        within('#search-questions-results') do
          click_link 'Include question'
        end

        expect(page).to have_content 'Question added to this poll'

        visit admin_poll_path(poll)

        expect(page).to have_content 'Questions (1)'
        expect(page).to_not have_content 'There are no questions assigned to this poll'
        expect(page).to have_content question.title
      end

      scenario 'Remove question from poll', :js do
        poll = create(:poll)
        question = create(:poll_question, poll: poll)

        visit admin_poll_path(poll)

        expect(page).to have_content 'Questions (1)'
        expect(page).to_not have_content 'There are no questions assigned to this poll'
        expect(page).to have_content question.title

        within("#poll_question_#{question.id}") do
          click_link 'Remove question from poll'
        end

        expect(page).to have_content 'Question removed from this poll'

        visit admin_poll_path(poll)

        expect(page).to have_content 'Questions (0)'
        expect(page).to have_content 'There are no questions assigned to this poll'
        expect(page).to_not have_content question.title
      end

    end
  end

  context "Recounting" do
    context "Poll show" do
      scenario "No recounts", :js do
        poll = create(:poll)
        visit admin_poll_path(poll)
        click_link "Recounting"

        expect(page).to have_content "There is nothing to be recounted"
      end

      scenario "Recounts list", :js do
        poll = create(:poll)
        booth_assignment = create(:poll_booth_assignment, poll: poll)
        booth_assignment_recounted = create(:poll_booth_assignment, poll: poll)
        booth_assignment_final_recounted = create(:poll_booth_assignment, poll: poll)

        3.times do |i|
          create(:poll_final_recount,
                 booth_assignment: booth_assignment,
                 date: poll.starts_at + i.days,
                 count: 21)
        end

        2.times { create(:poll_voter, booth_assignment: booth_assignment_final_recounted) }

        create(:poll_final_recount,
               booth_assignment: booth_assignment_final_recounted,
               date: poll.ends_at,
               count: 55555)

        visit admin_poll_path(poll)

        click_link "Recounting"

        expect(page).to have_css ".booth_recounts", count: 3

        within("#poll_booth_assignment_#{booth_assignment.id}_recounts") do
          expect(page).to have_content(booth_assignment.booth.name)
          expect(page).to have_content('63')
        end

        within("#poll_booth_assignment_#{booth_assignment_recounted.id}_recounts") do
          expect(page).to have_content(booth_assignment_recounted.booth.name)
          expect(page).to have_content('-')
        end

        within("#poll_booth_assignment_#{booth_assignment_final_recounted.id}_recounts") do
          expect(page).to have_content(booth_assignment_final_recounted.booth.name)
          expect(page).to have_content('55555')
          expect(page).to have_content('2')
        end
      end
    end
  end

  context "Results" do
    context "Poll show" do
      scenario "No results", :js do
        poll = create(:poll)
        visit admin_poll_path(poll)
        click_link "Results"

        expect(page).to have_content "There are no results"
      end

      scenario "Results by answer", :js do
        poll = create(:poll)
        booth_assignment_1 = create(:poll_booth_assignment, poll: poll)
        booth_assignment_2 = create(:poll_booth_assignment, poll: poll)
        booth_assignment_3 = create(:poll_booth_assignment, poll: poll)

        question_1 = create(:poll_question, poll: poll, valid_answers: "Yes,No")
        question_2 = create(:poll_question, poll: poll, valid_answers: "Today,Tomorrow")

        [booth_assignment_1, booth_assignment_2, booth_assignment_3].each do |ba|
          create(:poll_partial_result,
                  booth_assignment: ba,
                  question: question_1,
                  answer: 'Yes',
                  amount: 11)
          create(:poll_partial_result,
                  booth_assignment: ba,
                  question: question_2,
                  answer: 'Tomorrow',
                  amount: 5)
        end
        create(:poll_white_result,
               booth_assignment: booth_assignment_1,
               amount: 21)
        create(:poll_null_result,
               booth_assignment: booth_assignment_3,
               amount: 44)

        visit admin_poll_path(poll)

        click_link "Results"

        expect(page).to have_content(question_1.title)
        question_1.valid_answers.each_with_index do |answer, i|
          within("#question_#{question_1.id}_#{i}_result") do
            expect(page).to have_content(answer)
            expect(page).to have_content([33, 0][i])
          end
        end

        expect(page).to have_content(question_2.title)
        question_2.valid_answers.each_with_index do |answer, i|
          within("#question_#{question_2.id}_#{i}_result") do
            expect(page).to have_content(answer)
            expect(page).to have_content([0, 15][i])
          end
        end

        within('#white_results') { expect(page).to have_content('21') }
        within('#null_results') { expect(page).to have_content('44') }
      end
    end
  end

end
